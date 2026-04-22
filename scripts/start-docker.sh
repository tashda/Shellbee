#!/bin/sh
# Pre-test action: ensure the Z2M Docker stack is running.
# Called automatically by Xcode before each test run.
# If Docker is not installed or not running, this exits silently so tests auto-skip integration tests.
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
cd "$SRCROOT" || exit 0
docker compose up -d 2>/dev/null || true
