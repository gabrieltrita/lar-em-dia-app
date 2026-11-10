#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ] || { [ "$3" != "true" ] && [ "$3" != "false" ]; }; then
  echo "Usage: tool/prepare_web_build.sh WEB_DIR SITE_URL true|false" >&2
  exit 64
fi

web_dir="$1"
site_url="${2%/}"
indexable="$3"

if [[ ! "$site_url" =~ ^https://[a-z0-9.-]+$ ]]; then
  echo "SITE_URL must be https://host, got: $site_url" >&2
  exit 64
fi

for file in "$web_dir"/*.html "$web_dir/robots.txt" "$web_dir/sitemap.xml"; do
  sed -i "s|__SITE_URL__|$site_url|g" "$file"
done

if [ "$indexable" = "false" ]; then
  sed -i 's|<meta name="robots" content="index, follow">|<meta name="robots" content="noindex, nofollow">|' "$web_dir"/*.html
  printf 'User-agent: *\nAllow: /\n' > "$web_dir/robots.txt"
  rm "$web_dir/sitemap.xml"
fi
