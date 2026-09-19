# Unity WebGL builds

Builds are **not** committed to git (see `.gitignore`). They are uploaded
straight to S3 by `scripts/deploy-game.sh`.

Local layout, one directory per game:

    games/
      my-game/
        index.html
        Build/
          my-game.loader.js
          my-game.framework.js.br
          my-game.wasm.br
          my-game.data.br

Served at `https://jasonpanoff.com/games/my-game/`.

**Critical:** `.br` files must be uploaded with BOTH the correct
`Content-Type` (e.g. `application/wasm`) and `Content-Encoding: br`, or the
browser downloads compressed bytes it never decompresses and the game shows
a blank canvas. The deploy script handles this — do not plain `aws s3 sync`
this directory.
