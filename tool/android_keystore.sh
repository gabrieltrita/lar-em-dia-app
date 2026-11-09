#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 2 ]; then
  echo "Usage: tool/android_keystore.sh [KEYSTORE_PATH] [OWNER/REPO]" >&2
  exit 64
fi

keystore="${1:-$HOME/lar-em-dia-upload.jks}"
repository="${2:-gabrieltrita/lar-em-dia-app}"
alias="upload"

if [ -e "$keystore" ]; then
  echo "$keystore already exists; choose another path or move it away first" >&2
  exit 1
fi

read -rsp "Password for the upload key (at least 8 characters): " ANDROID_KEY_PASSWORD
echo
read -rsp "Repeat the password: " repeated
echo
if [ "$ANDROID_KEY_PASSWORD" != "$repeated" ]; then
  echo "The passwords do not match" >&2
  exit 1
fi
if [ "${#ANDROID_KEY_PASSWORD}" -lt 8 ]; then
  echo "The password needs at least 8 characters" >&2
  exit 1
fi
export ANDROID_KEY_PASSWORD

keytool -genkeypair -keystore "$keystore" -alias "$alias" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass:env ANDROID_KEY_PASSWORD -keypass:env ANDROID_KEY_PASSWORD -dname "CN=Lar em Dia" 2>/dev/null

base64 < "$keystore" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$repository"
printf '%s' "$ANDROID_KEY_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$repository"
printf '%s' "$ANDROID_KEY_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD --repo "$repository"
printf '%s' "$alias" | gh secret set ANDROID_KEY_ALIAS --repo "$repository"

echo "Upload key saved to $keystore and stored in the secrets of $repository."
echo "Keep a copy of the file and the password outside this machine."
echo
keytool -list -v -keystore "$keystore" -alias "$alias" -storepass:env ANDROID_KEY_PASSWORD 2>/dev/null \
  | grep -E '^\s*SHA1:' | sed 's/^\s*/Upload key /'
