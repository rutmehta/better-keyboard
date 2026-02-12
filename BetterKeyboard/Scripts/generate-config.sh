#!/bin/bash
# generate-config.sh — Creates ProductConfig.swift and PromptTemplates.swift
# from environment variables (set via GitHub Secrets in CI, or .env locally).
#
# Usage:
#   ./Scripts/generate-config.sh          # uses env vars or falls back to .example files
#   source .env && ./Scripts/generate-config.sh  # local dev with .env file
#
# Required secrets (set in GitHub repo → Settings → Secrets → Actions):
#   PRODUCT_CONFIG_SWIFT   — full contents of ProductConfig.swift
#   PROMPT_TEMPLATES_SWIFT — full contents of PromptTemplates.swift

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PRODUCT_CONFIG_PATH="$PROJECT_DIR/Shared/ProductConfig.swift"
PROMPT_TEMPLATES_PATH="$PROJECT_DIR/App/AI/PromptTemplates.swift"

# --- ProductConfig.swift ---
if [ -n "${PRODUCT_CONFIG_SWIFT:-}" ]; then
    echo "Generating ProductConfig.swift from secret..."
    echo "$PRODUCT_CONFIG_SWIFT" > "$PRODUCT_CONFIG_PATH"
elif [ ! -f "$PRODUCT_CONFIG_PATH" ]; then
    echo "No PRODUCT_CONFIG_SWIFT secret found. Copying from .example..."
    cp "$PROJECT_DIR/Shared/ProductConfig.example.swift" "$PRODUCT_CONFIG_PATH"
fi

# --- PromptTemplates.swift ---
if [ -n "${PROMPT_TEMPLATES_SWIFT:-}" ]; then
    echo "Generating PromptTemplates.swift from secret..."
    echo "$PROMPT_TEMPLATES_SWIFT" > "$PROMPT_TEMPLATES_PATH"
elif [ ! -f "$PROMPT_TEMPLATES_PATH" ]; then
    echo "No PROMPT_TEMPLATES_SWIFT secret found. Copying from .example..."
    cp "$PROJECT_DIR/App/AI/PromptTemplates.example.swift" "$PROMPT_TEMPLATES_PATH"
fi

echo "Config generation complete."
