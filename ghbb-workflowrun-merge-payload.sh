#!/usr/bin/env bash
set -euo pipefail
marker='GHBB-WORKFLOWRUN-MERGE-PAYLOAD-20260726'
secret_sha256="$(printf '%s' "${GHBB_DUMMY_SECRET:?missing dummy secret}" | sha256sum | cut -d' ' -f1)"
{
  printf 'marker=%s\n' "$marker"
  printf 'secret_sha256=%s\n' "$secret_sha256"
  printf 'source=pr-merge-commit-controlled-script\n'
} > ghbb-workflowrun-merge-proof.txt
