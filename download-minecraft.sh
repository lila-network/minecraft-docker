#!/usr/bin/env bash
set -Eeuo pipefail

MC_VERSION="${1:-}"
TARGET_PATH="${2:-./server.jar}"

MANIFEST_URL="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"

die() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"
}

curl_download() {
  local url="$1"
  local output="$2"

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
    "$url" \
    --output "$output"
}

verify_sha1() {
  local expected="$1"
  local file="$2"

  if command -v sha1sum >/dev/null 2>&1; then
    echo "${expected}  ${file}" | sha1sum -c -
  elif command -v shasum >/dev/null 2>&1; then
    echo "${expected}  ${file}" | shasum -a 1 -c -
  else
    die "Neither 'sha1sum' nor 'shasum' is available"
  fi
}

if [[ -z "$MC_VERSION" ]]; then
  cat >&2 <<EOF
Usage:
  $0 <minecraft-version> [target-path]

Examples:
  $0 26.1.1
  $0 26.1.1 /opt/minecraft/server.jar
EOF
  exit 1
fi

require_command curl
require_command jq

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MANIFEST_FILE="$TMP_DIR/manifest.json"
VERSION_FILE="$TMP_DIR/version.json"
DOWNLOAD_FILE="$TMP_DIR/server.jar"

info "Downloading Minecraft version manifest"
curl_download "$MANIFEST_URL" "$MANIFEST_FILE"

VERSION_URL="$(
  jq -er --arg version "$MC_VERSION" '
    .versions[]
    | select(.id == $version)
    | .url
  ' "$MANIFEST_FILE"
)" || die "Minecraft version '$MC_VERSION' was not found"

info "Downloading metadata for Minecraft $MC_VERSION"
curl_download "$VERSION_URL" "$VERSION_FILE"

SERVER_URL="$(
  jq -er '.downloads.server.url' "$VERSION_FILE"
)" || die "No server download URL found for Minecraft version '$MC_VERSION'"

SERVER_SHA1="$(
  jq -er '.downloads.server.sha1' "$VERSION_FILE"
)" || die "No SHA1 checksum found for Minecraft version '$MC_VERSION'"

info "Downloading Minecraft server $MC_VERSION"
curl_download "$SERVER_URL" "$DOWNLOAD_FILE"

info "Verifying SHA1 checksum"
verify_sha1 "$SERVER_SHA1" "$DOWNLOAD_FILE"

mkdir -p "$(dirname "$TARGET_PATH")"
mv "$DOWNLOAD_FILE" "$TARGET_PATH"

info "Minecraft server $MC_VERSION downloaded to $TARGET_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "minecraft_version=$MC_VERSION"
    echo "server_jar=$TARGET_PATH"
    echo "server_sha1=$SERVER_SHA1"
  } >> "$GITHUB_OUTPUT"
fi