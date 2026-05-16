# EdgeRun Agent scripts

This directory contains scripts used by `edgerun-agent`, the always-on local agent service.

## Default run flow

`run.sh`:

- runs `make`
- runs `make netboot`
- calls `collect.sh` to collect diagnostics
- writes logs to `agent-output/latest/run.log`

`collect.sh` writes these files in the output directory:

- `summary.txt`
- `git-status.txt`
- `build.txt`
- `netboot-status.txt`
- `netboot-journal.txt`
- `network.txt`
- `sockets.txt`
- `boot-artifacts.txt`
- `timestamp.txt`

## Safety

Do not run scripts from random paths.
`run.sh` can be replaced in your branch with custom behavior and `edgerun-agent` will execute only the configured `EDGERUN_AGENT_RUN_SCRIPT`.
