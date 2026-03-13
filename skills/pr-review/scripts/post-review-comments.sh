#!/bin/bash
# Backward-compatible wrapper for the provider-neutral reply script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/post-ai-review-comments.sh" "$@"
