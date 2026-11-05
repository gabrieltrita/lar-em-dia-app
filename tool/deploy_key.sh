#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || { [ "$1" != "staging" ] && [ "$1" != "production" ]; }; then
  echo "Usage: tool/deploy_key.sh staging|production HOST [OWNER/REPO]" >&2
  exit 64
fi

environment="$1"
host="$2"
repository="${3:-gabrieltrita/lar-em-dia-app}"
prefix=""
if [ "$environment" = "staging" ]; then
  prefix="STAGING_"
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

ssh-keygen -q -t ed25519 -N "" -C "laremdia-web-$environment-deploy" -f "$workdir/deploy_key"
ssh-keyscan -t ed25519 "$host" > "$workdir/known_hosts" 2>/dev/null
if [ ! -s "$workdir/known_hosts" ]; then
  echo "Could not read the SSH host key of $host" >&2
  exit 1
fi

gh secret set "${prefix}DEPLOY_SSH_PRIVATE_KEY" --repo "$repository" < "$workdir/deploy_key"
gh secret set "${prefix}DEPLOY_SSH_KNOWN_HOSTS" --repo "$repository" < "$workdir/known_hosts"

echo "Host key of $host: $(ssh-keygen -l -f "$workdir/known_hosts")"
echo
echo "Append this line to ~/.ssh/authorized_keys of the deploy user on $host:"
cat "$workdir/deploy_key.pub"
