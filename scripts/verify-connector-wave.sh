#!/usr/bin/env bash
# verify-connector-wave.sh — Serial connector-wave verification gate.
#
# Runs root compile --warnings-as-errors, then package tests for each
# connector one at a time (avoids Mix build lock contention).
#
# Usage:
#   ./scripts/verify-connector-wave.sh
#   ./scripts/verify-connector-wave.sh --skip-compile
#   ./scripts/verify-connector-wave.sh --package webhook --package calcom
#
# See pi-connector-factory/README.md for full documentation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES=(calcom hubspot airtable webhook jira linear posthog calendly salesforce)

SKIP_COMPILE=false
SELECTED=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-compile) SKIP_COMPILE=true; shift ;;
    --package)
      SELECTED+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ${#SELECTED[@]} -gt 0 ]]; then
  PACKAGES=("${SELECTED[@]}")
fi

PASS=()
FAIL=()

echo "=== Connector Wave Verification ==="
echo ""

# Phase 1: Root compile / warnings check
if [[ "$SKIP_COMPILE" == "false" ]]; then
  echo "[1/2] Root compile --warnings-as-errors ..."
  if (cd "$REPO_ROOT" && mix compile --warnings-as-errors --no-deps-check > /dev/null 2>&1); then
    PASS+=("root-compile")
    echo "  ok   root-compile"
  else
    FAIL+=("root-compile")
    echo "  FAIL root-compile"
    (cd "$REPO_ROOT" && mix compile --warnings-as-errors --no-deps-check 2>&1 || true) | tail -5 | sed 's/^/       /'
  fi
  echo ""
else
  echo "[1/2] Root compile -- skipped (--skip-compile)"
  echo ""
fi

# Phase 2: Serial package tests
echo "[2/2] Package tests (${#PACKAGES[@]} packages, serial) ..."

for pkg in "${PACKAGES[@]}"; do
  app_dir="$REPO_ROOT/apps/jido_connect_${pkg}"
  if [[ ! -d "$app_dir" ]]; then
    FAIL+=("$pkg")
    echo "  FAIL $pkg (dir missing: $app_dir)"
    continue
  fi

  if (cd "$app_dir" && mix test --no-deps-check > /dev/null 2>&1); then
    PASS+=("$pkg")
    echo "  ok   $pkg"
  else
    FAIL+=("$pkg")
    echo "  FAIL $pkg"
    (cd "$app_dir" && mix test --no-deps-check 2>&1 || true) | tail -3 | sed 's/^/       /'
  fi
done

# Summary
echo ""
echo "=== Summary ==="
for name in "${PASS[@]+${PASS[@]}}"; do echo "  PASS  $name"; done
for name in "${FAIL[@]+${FAIL[@]}}"; do echo "  FAIL  $name"; done
PASS_COUNT=${#PASS[@]}
FAIL_COUNT=${#FAIL[@]}
echo ""
echo "${PASS_COUNT} passed, ${FAIL_COUNT} failed, $(( PASS_COUNT + FAIL_COUNT )) total"

if [[ ${#FAIL[@]} -gt 0 ]]; then
  exit 1
fi
