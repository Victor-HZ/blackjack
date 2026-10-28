#!/usr/bin/env bash
# Install the official Swift 6.2 Ubuntu 24.04 x86_64 toolchain without root.
# Validated on Debian 13. This does not provide Xcode, SwiftUI, or the iOS SDK.
set -euo pipefail

swift_version='6.2'
archive_name='swift-6.2-RELEASE-ubuntu24.04.tar.gz'
archive_sha256='8e3d63a3371caad495e694414b9b9a22c5f68c6473077406c7296472a41bc077'
signing_fingerprint='52BB7E3DE28A71BE22EC05FFEF80A866B47A981F'
release_base='https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE'
key_url='https://raw.githubusercontent.com/swiftlang/swift-org-website/main/keys/release-key-swift-6.x.asc'
install_prefix="${SWIFT_INSTALL_PREFIX:-/workspace/.toolchains/swift-6.2}"
download_cache="${SWIFT_DOWNLOAD_CACHE:-/tmp/swift-6.2-download}"
marker="$install_prefix/.verified-archive-sha256"

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'This installer supports Linux x86_64 only. Use Xcode on macOS for the iOS app.' >&2
  exit 1
fi

# Reuse only a completed installation produced after successful verification.
if [[ -x "$install_prefix/usr/bin/swift" && -f "$marker" ]] && [[ "$(cat "$marker")" == "$archive_sha256" ]]; then
  "$install_prefix/usr/bin/swift" --version
  echo "Verified Swift $swift_version installation already exists at $install_prefix"
  exit 0
fi
if [[ -e "$install_prefix" ]]; then
  echo "Refusing to overwrite an existing, unrecognized installation: $install_prefix" >&2
  exit 1
fi

for requirement in curl gpg sha256sum tar awk mktemp; do
  command -v "$requirement" >/dev/null || { echo "Required command is missing: $requirement" >&2; exit 1; }
done
mkdir -p "$download_cache" "$(dirname "$install_prefix")"
gpg_directory="$(mktemp -d "$download_cache/verification.XXXXXX")"
staging_directory=''
cleanup() {
  rm -rf -- "$gpg_directory"
  if [[ -n "$staging_directory" && -d "$staging_directory" ]]; then rm -rf -- "$staging_directory"; fi
}
trap cleanup EXIT

fetch() {
  local source_url="$1" destination="$2"
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 \
    --proto '=https' --proto-redir '=https' "$source_url" --output "$destination.partial"
  mv -- "$destination.partial" "$destination"
}

archive_path="$download_cache/$archive_name"
signature_path="$archive_path.sig"
if [[ ! -f "$archive_path" ]]; then fetch "$release_base/$archive_name" "$archive_path"; fi
if [[ ! -f "$signature_path" ]]; then fetch "$release_base/$archive_name.sig" "$signature_path"; fi
# Read the current official key, including any subsequently published revocation.
fetch "$key_url" "$gpg_directory/swift-release-key.asc"
gpg --homedir "$gpg_directory" --batch --no-autostart --import "$gpg_directory/swift-release-key.asc"
actual_fingerprint="$(gpg --homedir "$gpg_directory" --batch --no-autostart --with-colons --fingerprint | awk -F: '$1 == "fpr" { print $10; exit }')"
if [[ "$actual_fingerprint" != "$signing_fingerprint" ]]; then
  echo 'Swift release-key fingerprint did not match the documented official key.' >&2
  exit 1
fi

gpg --homedir "$gpg_directory" --batch --no-autostart --status-fd 1 \
  --verify "$signature_path" "$archive_path" > "$gpg_directory/signature-status.txt"
awk -v expected="$signing_fingerprint" '$2 == "VALIDSIG" && $3 == expected { valid = 1 } END { exit !valid }' "$gpg_directory/signature-status.txt"
printf '%s  %s\n' "$archive_sha256" "$archive_path" | sha256sum --check --status

# Extraction and execution happen only after signature AND checksum validation.
staging_directory="$(mktemp -d "$(dirname "$install_prefix")/.swift-install.XXXXXX")"
tar -xzf "$archive_path" --strip-components=1 -C "$staging_directory"
"$staging_directory/usr/bin/swift" --version
printf '%s\n' "$archive_sha256" > "$staging_directory/.verified-archive-sha256"
mv -- "$staging_directory" "$install_prefix"
staging_directory=''
echo "Installed verified Swift $swift_version at $install_prefix"
echo "Use $install_prefix/usr/bin/swift explicitly or add its usr/bin directory to PATH for this shell."
