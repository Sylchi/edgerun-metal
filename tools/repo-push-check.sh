#!/usr/bin/env sh
set -eu

# Purpose:
#   Fail before pushing commits that contain blobs GitHub will reject.
# Intention:
#   Keep remote push failures deterministic and local.

BASE_REF=${ER_PUSH_CHECK_BASE:-origin/main}
LIMIT_BYTES=${ER_PUSH_BLOB_LIMIT_BYTES:-100000000}
TMP_FILE=$(mktemp)

cleanup() {
  rm -f "${TMP_FILE}"
}
trap cleanup EXIT

if ! git rev-parse --verify "${BASE_REF}" >/dev/null 2>&1; then
  printf 'repo-push-check: missing base ref %s\n' "${BASE_REF}" >&2
  exit 1
fi

git rev-list --objects "${BASE_REF}..HEAD" |
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' > "${TMP_FILE}"

failed=0
while IFS=' ' read -r object_type object_id object_size object_path; do
  if [ "${object_type}" != "blob" ]; then
    continue
  fi
  if [ "${object_size}" -gt "${LIMIT_BYTES}" ]; then
    failed=1
    printf 'repo-push-check: oversized blob %s bytes=%s path=%s\n' \
      "${object_id}" "${object_size}" "${object_path}" >&2
  fi
done < "${TMP_FILE}"

if [ "${failed}" -ne 0 ]; then
  printf 'repo-push-check: push would be rejected; blob limit is %s bytes\n' \
    "${LIMIT_BYTES}" >&2
  exit 1
fi

printf 'repo-push-check passed\n'
