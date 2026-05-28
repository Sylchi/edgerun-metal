#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "crates/edgerun-codex/host/src/pipeline.rs" ] || [ ! -f "crates/edgerun-codex/host/src/main.rs" ]; then
  echo "Run from edgerun repo root" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

pipeline = Path("crates/edgerun-codex/host/src/pipeline.rs")
text = pipeline.read_text()

replacements = {
    "- Repository work happens in the in-memory repo workspace and is written back immediately after Executor edits.\\n":
    "- Repository work happens in the in-memory repo workspace.\\n",
    "- The host will apply those edits in memory and immediately write changed files back to disk.\\n":
    "- The host applies those edits to memory only. Disk stays untouched until the user explicitly commits.\\n",
    "- Review the already-written repo diff from the Executor stage.\\n":
    "- Review the pending in-memory repo diff from the Executor stage.\\n",
    "- Return Verdict: accept only when the diff should be written back to disk.\\n":
    "",
    "- Mention whether the repo work stayed inside the in-memory workspace boundary.\\n":
    "- Mention that repo edits are pending in memory until the user commits.\\n",
    "output.text = apply_repo_edits_and_writeback_from_executor(&output.text, repo, observer)?;":
    "output.text = apply_repo_edits_from_executor(&output.text, repo, observer)?;",
    "fn apply_repo_edits_and_writeback_from_executor(":
    "fn apply_repo_edits_from_executor(",
    '- The host applies repo_edit in memory, produces RepoDiff, and writes changed files back immediately.\\n':
    '- The host applies repo_edit in memory only and shows the pending diff.\\n',
    '- Reviewer audits the already-written diff and gives corrected guidance for the next turn when needed.\\n':
    '- Disk and git remain unchanged until the user explicitly commits.\\n',
    'Repository work stays inside the in-memory workspace during editing and writes back immediately after Executor.':
    'Repository edits stay in memory until explicit user commit.',
    'Boundary: repo operations stay in memory and write back after Executor; host_shell only on explicit non-repo request.':
    'Boundary: repo operations stay in memory until user commit; host_shell only on explicit non-repo request.',
}
for old, new in replacements.items():
    text = text.replace(old, new)

old_block = '''    let diff = repo.diff();
    text.push_str("\\nRepoDiff:\\n");
    text.push_str(&diff);

    let written = write_back_changed_files(repo, observer)?;
    if !written.is_empty() {
        text.push_str("\\nRepoWriteback:\\n");
        text.push_str(&written);
    }

    Ok(truncate_chars(&text, MAX_STAGE_OUTPUT_CHARS))
}

fn write_back_changed_files(
    repo: &mut dyn RepoTools,
    observer: &mut dyn PipelineObserver,
) -> Result<String, BoxError> {
    let mut out = String::new();
    for path in repo.changed_files() {
        let ok = repo.write_back(&path).is_ok();
        observer.repo_written(&path, ok)?;
        out.push_str("- ");
        out.push_str(&path);
        out.push_str(if ok { " written\\n" } else { " write failed\\n" });
    }
    Ok(out)
}
'''
new_block = '''    text.push_str("\\nRepoDiffPendingInMemory:\\n");
    text.push_str(&repo.diff());
    text.push_str("\\nPendingWriteback:\\n");
    for path in repo.changed_files() {
        text.push_str("- ");
        text.push_str(&path);
        text.push('\\n');
    }

    Ok(truncate_chars(&text, MAX_STAGE_OUTPUT_CHARS))
}
'''
if old_block in text:
    text = text.replace(old_block, new_block)

for marker in ["fn write_back_changed_files(", "fn reviewer_accepts("]:
    if marker in text:
        start = text.index(marker)
        brace = text.index("{", start)
        depth = 0
        end = None
        for i in range(brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        if end is not None:
            text = text[:start] + text[end:]

test_marker = '    #[test]\n    fn reviewer_accepts_exact_verdict()'
if test_marker in text:
    start = text.index(test_marker)
    next_test = text.find('    #[test]', start + len(test_marker))
    if next_test == -1:
        mod_end = text.rfind("\n}")
        text = text[:start] + text[mod_end:]
    else:
        text = text[:start] + text[next_test:]

pipeline.write_text(text)

main = Path("crates/edgerun-codex/host/src/main.rs")
text = main.read_text()

if "use crate::pipeline::PipelineObserver;" not in text:
    text = text.replace("mod ui_stream;\n", "mod ui_stream;\n\nuse crate::pipeline::PipelineObserver;\n")

if "fn is_commit_command(" not in text:
    insert_at = text.index("#[allow(clippy::too_many_arguments)]\nfn handle_chat_envelope")
    helpers = r'''
fn is_commit_command(value: &str) -> bool {
    let normalized = value.trim().to_ascii_lowercase();
    matches!(
        normalized.as_str(),
        "commit" | "/commit" | "commit repo" | "writeback" | "/writeback"
    )
}

fn commit_pending_repo_changes(
    repo_workspace: &mut repo_workspace::RepoWorkspace,
    ui_sink: &mut UiStreamSink,
) -> Result<String, Box<dyn Error>> {
    let changed = repo_workspace.changed_files();
    if changed.is_empty() {
        return Ok("No pending in-memory repo changes to commit.".to_string());
    }

    let mut out = String::from("Committed pending in-memory repo changes to disk:\n");
    for path in changed {
        let ok = repo_workspace.write_back(&path).is_ok();
        ui_sink.repo_written(&path, ok)?;
        out.push_str("- ");
        out.push_str(&path);
        out.push_str(if ok { " written\n" } else { " write failed\n" });
    }
    Ok(out)
}

'''
    text = text[:insert_at] + helpers + text[insert_at:]

old = '''    let thread_state = threads.entry(message.from).or_default();
    thread_state.previous_message_hash = message.message_id;
    thread_state.next_sequence = thread_state
        .next_sequence
        .max(message.sequence.saturating_add(1));
    thread_state.history.push(user_item(text.clone()));

    let repo_context = repo_workspace.context_for_request(&text);
'''
new = '''    let thread_state = threads.entry(message.from).or_default();
    thread_state.previous_message_hash = message.message_id;
    thread_state.next_sequence = thread_state
        .next_sequence
        .max(message.sequence.saturating_add(1));
    thread_state.history.push(user_item(text.clone()));

    if is_commit_command(&text) {
        let reply = commit_pending_repo_changes(repo_workspace, ui_sink)?;
        thread_state.history.push(assistant_item(reply.clone()));
        let response = signed_chat_response(
            agent_key,
            agent,
            &sender,
            message.via_relay,
            envelope.channel_id,
            envelope.route_hash,
            thread_state.next_sequence,
            thread_state.previous_message_hash,
            reply.as_bytes(),
        )?;
        thread_state.previous_message_hash = response.message_id;
        thread_state.next_sequence = thread_state.next_sequence.saturating_add(1);
        hub.send_envelope_to(sender.node_id, &response.envelope)?;
        ui_sink.assistant_draft(&reply)?;
        ui_sink.status("ready")?;
        return Ok(());
    }

    let repo_context = repo_workspace.context_for_request(&text);
'''
if old not in text:
    raise SystemExit("Could not locate insertion point for commit command")
text = text.replace(old, new)
main.write_text(text)
PY

echo "Fixed: repo edits stay in memory until explicit user commit."
echo "Run: cargo test -p codex-host"
