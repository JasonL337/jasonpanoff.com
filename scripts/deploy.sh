#!/usr/bin/env bash
# Deploy the static site to S3 and invalidate the CloudFront cache.
#
#   bash scripts/deploy.sh            # deploy
#   bash scripts/deploy.sh --dry-run  # show what would change, touch nothing
#
# Unity builds are NOT handled here — see deploy-game.sh. They are excluded
# from the sync (including from --delete) so this script can never remove them.

set -euo pipefail

BUCKET="jasonpanoff-com-site"
DISTRIBUTION_ID="E2OWGQLWY22666"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY=""
[[ "${1:-}" == "--dry-run" ]] && DRY="--dryrun"

# Files that live in the repo but must never reach the bucket.
EXCLUDES=(
  --exclude ".git/*"
  --exclude ".github/*"
  --exclude "games/*"
  --exclude "scripts/*"
  --exclude "infra/*"
  --exclude "*.md"
  --exclude ".gitignore"
  --exclude ".gitattributes"
)

echo "==> Syncing assets (1 day cache)"
# Everything except HTML. These are invalidated on every deploy, so a longer
# TTL is safe and keeps repeat visits fast.
aws s3 sync "$ROOT" "s3://$BUCKET" \
  $DRY --delete \
  "${EXCLUDES[@]}" --exclude "*.html" \
  --cache-control "public, max-age=86400"

echo "==> Syncing HTML (no-cache)"
# HTML is the entry point to everything else. no-cache does not mean "never
# cache" -- it means the browser must revalidate before reuse, so a deploy is
# visible immediately while unchanged pages still return a cheap 304.
aws s3 sync "$ROOT" "s3://$BUCKET" \
  $DRY \
  "${EXCLUDES[@]}" --exclude "*" --include "*.html" \
  --cache-control "no-cache"

if [[ -n "$DRY" ]]; then
  echo "==> Dry run: skipping invalidation"
  exit 0
fi

echo "==> Invalidating CloudFront"
# Without this, edges keep serving the old copy until their TTL expires.
# "/*" counts as a single path against the monthly free allowance.
ID=$(aws cloudfront create-invalidation \
      --distribution-id "$DISTRIBUTION_ID" \
      --paths "/*" \
      --query 'Invalidation.Id' --output text)

echo "==> Invalidation $ID created (usually completes in 1-3 min)"
echo "==> Done: https://jasonpanoff.com/"
