#!/usr/bin/env bash
# Download and import the GitHub Web Flow GPG key, and set a local trust level to "full".
# This will allow us to verify the signature of commits made by GitHub Web Flow.

set -euo pipefail

echo "Downloading and importing the GitHub Web Flow GPG key..."

key="$(mktemp)"
trap 'rm -f "$key"' EXIT

curl -sSL https://github.com/web-flow.gpg -o "$key"

gpg --batch --import "$key"
echo "$(gpg --with-colons --show-keys "$key" | awk -F: '$1=="fpr"{print $10 ":6:"}')" | gpg --import-ownertrust
gpg --check-trustdb
