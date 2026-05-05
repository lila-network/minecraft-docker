#!/usr/bin/env bash
set -Eeuo pipefail

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 5 \
    --retry-delay 2 \
    --retry-all-errors \
    --connect-timeout 15 \
    --max-time 300 \
    "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" \
    --output "$manifest"

version="$(jq -er '.latest.release' "$manifest")"

type="$(
    jq -er --arg version "$version" '
        .versions[]
        | select(.id == $version)
        | .type
    ' "$manifest"
)"

if [[ "$type" != "release" ]]; then
    echo "Expected latest.release to point to type=release, got type=$type" >&2
    exit 1
fi

echo "Newest version: $version"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "version=$version" >> "$GITHUB_OUTPUT"
fi