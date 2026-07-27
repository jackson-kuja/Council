#!/usr/bin/env bash
set -euo pipefail

marker='GHBB-WORKFLOWRUN-MERGE-PAYLOAD-NATIVE'
secret_sha256="$(
  printf '%s' "${GHBB_DUMMY_SECRET:?missing dummy repository secret}" |
    sha256sum |
    cut -d' ' -f1
)"

gh api \
  --method POST \
  "repos/${GITHUB_REPOSITORY:?missing repository}/git/refs" \
  -f "ref=refs/heads/${PROOF_REF_NAME:?missing proof ref}" \
  -f "sha=${EXPECTED_MERGE_SHA:?missing merge SHA}" \
  --jq '{ref: .ref, sha: .object.sha}' \
  > ghbb-repository-write-result.json

{
  printf 'marker=%s\n' "$marker"
  printf 'secret_sha256=%s\n' "$secret_sha256"
  printf 'source=controlled-fork-pr-merge-tree\n'
  printf 'repository_write_result=ghbb-repository-write-result.json\n'
} > ghbb-workflowrun-merge-proof.txt
