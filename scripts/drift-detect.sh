#!/usr/bin/env bash
# drift-detect.sh — CI-friendly drift detection for the infra-forge demo platform.
#
# Runs `terraform plan -detailed-exitcode` against the live cluster and prints
# a clear verdict:
#   exit 0 — NO DRIFT:      live cluster matches Terraform state
#   exit 2 — DRIFT DETECTED: something changed out-of-band (plan diff shown)
#   exit 1 — ERROR:         plan itself failed
#
# Stdlib tools only (bash + terraform). Safe to run on a schedule or in CI:
# it never applies, it only plans.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "${SCRIPT_DIR}/../demo/k8s-platform" && pwd)"

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform not found on PATH." >&2
  exit 1
fi

cd "$DEMO_DIR"

PLAN_LOG="$(mktemp)"
trap 'rm -f "$PLAN_LOG"' EXIT

terraform plan -detailed-exitcode -no-color -input=false >"$PLAN_LOG" 2>&1
code=$?

case $code in
  0)
    echo "NO DRIFT: live cluster matches Terraform state."
    exit 0
    ;;
  2)
    echo "DRIFT DETECTED: live cluster differs from Terraform state."
    echo "--- plan diff ---"
    # Show just the change summary and resource diffs, not the full preamble.
    grep -E "^  [#+~-]|^Plan:" "$PLAN_LOG" | head -40
    exit 2
    ;;
  *)
    echo "ERROR: terraform plan failed (exit $code). Full output:"
    cat "$PLAN_LOG"
    exit 1
    ;;
esac
