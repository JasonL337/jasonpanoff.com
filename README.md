# jasonpanoff.com

Static portfolio site. Plain HTML/CSS/JS — no build step.

## Layout

    index.html        homepage
    css/ js/          styles and scripts
    assets/img/       images
    projects/         project write-ups
    games/            Unity WebGL builds (NOT in git — see games/README.md)
    scripts/          deploy tooling

## Hosting

    jasonpanoff.com  ->  Route 53 (alias)  ->  CloudFront  ->  S3 (private, via OAC)

- Domain registered at Amazon Registrar; hosted zone lives in a separate AWS
  account from the S3/CloudFront resources. DNS works across accounts.
- Canonical host is the apex. `www` 301-redirects to it.
- ACM certificate must live in **us-east-1** for CloudFront to accept it.

## Deploying

Not wired up yet. Will be: sync to S3 -> invalidate CloudFront.
HTML gets a short cache TTL; hashed assets and game builds get a long one.
