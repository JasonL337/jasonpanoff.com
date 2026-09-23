#!/usr/bin/env bash
# Upload one Unity WebGL build to S3 with the metadata browsers require.
#
#   bash scripts/deploy-game.sh my-game
#
# Expects games/my-game/ to exist locally; serves it at /games/my-game/.
#
# WHY THIS EXISTS: a plain `aws s3 sync` uploads Unity's pre-compressed .br
# and .gz files without Content-Encoding. The browser then receives compressed
# bytes, never decompresses them, and the game fails with a blank canvas and
# an unhelpful console error. Every file below needs BOTH the right
# Content-Type and the right Content-Encoding.

set -euo pipefail

BUCKET="jasonpanoff-com-site"
DISTRIBUTION_ID="E2OWGQLWY22666"

GAME="${1:-}"
if [[ -z "$GAME" ]]; then
  echo "usage: bash scripts/deploy-game.sh <game-directory-name>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/games/$GAME"
DEST="s3://$BUCKET/games/$GAME"

[[ -d "$SRC" ]] || { echo "No such directory: $SRC" >&2; exit 1; }

# Build files are immutable once produced: a rebuild changes their contents,
# and you should bump the game directory name if you need a hard cache break.
IMMUTABLE="public, max-age=31536000, immutable"

content_type_for() {
  # Strip any .br/.gz suffix first, then match the real extension.
  local f="${1%.br}"; f="${f%.gz}"
  case "$f" in
    *.wasm)  echo "application/wasm" ;;
    *.js)    echo "application/javascript" ;;
    *.json)  echo "application/json" ;;
    *.html)  echo "text/html" ;;
    *.css)   echo "text/css" ;;
    *.data)  echo "application/octet-stream" ;;
    *)       echo "application/octet-stream" ;;
  esac
}

encoding_for() {
  case "$1" in
    *.br) echo "br" ;;
    *.gz) echo "gzip" ;;
    *)    echo "" ;;
  esac
}

echo "==> Uploading games/$GAME"
find "$SRC" -type f -print0 | while IFS= read -r -d '' file; do
  rel="${file#"$SRC"/}"
  ctype="$(content_type_for "$file")"
  enc="$(encoding_for "$file")"

  args=( --content-type "$ctype" )
  if [[ -n "$enc" ]]; then
    args+=( --content-encoding "$enc" )
  fi

  # The loader page itself must stay fresh so a redeploy is picked up.
  if [[ "$rel" == "index.html" ]]; then
    args+=( --cache-control "no-cache" )
  else
    args+=( --cache-control "$IMMUTABLE" )
  fi

  echo "    $rel  [$ctype${enc:+; $enc}]"
  aws s3 cp "$file" "$DEST/$rel" --only-show-errors "${args[@]}"
done

echo "==> Invalidating /games/$GAME/*"
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/games/$GAME/*" \
  --query 'Invalidation.Id' --output text

echo "==> Done: https://jasonpanoff.com/games/$GAME/"
