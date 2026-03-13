#!/bin/bash
# Backward-compatible wrapper for the provider-neutral thread resolver.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/resolve-ai-review-threads.sh" "$@"
