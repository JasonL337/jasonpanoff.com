#!/usr/bin/env bash
# One-time setup: let GitHub Actions deploy this site without stored AWS keys.
#
#   bash infra/setup-github-oidc.sh
#
# Creates three things in the current AWS account:
#   1. An OIDC identity provider trusting GitHub's token issuer.
#   2. An IAM role that only this repo's main branch may assume.
#   3. A least-privilege policy: write this bucket, invalidate this
#      distribution, nothing else.
#
# Safe to re-run; existing resources are left alone.

set -euo pipefail

GITHUB_REPO="JasonL337/jasonpanoff.com"  # case-sensitive: must match GitHub exactly
BRANCH="main"
BUCKET="jasonpanoff-com-site"
DISTRIBUTION_ID="E2OWGQLWY22666"
ROLE_NAME="github-actions-deploy"
POLICY_NAME="github-actions-deploy-policy"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "==> Account $ACCOUNT_ID"

# 1. OIDC provider -----------------------------------------------------------
# One per account, shared by every repo. Registers GitHub as an identity
# provider AWS is willing to believe.
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" >/dev/null 2>&1; then
  echo "==> OIDC provider already exists"
else
  echo "==> Creating OIDC provider"
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" >/dev/null
fi

# 2. Role and trust policy ---------------------------------------------------
# The "sub" condition is the security boundary. Without it, ANY GitHub repo
# in the world could assume this role.
TRUST=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${PROVIDER_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/${BRANCH}"
      }
    }
  }]
}
JSON
)

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "==> Role exists; updating trust policy"
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST"
else
  echo "==> Creating role $ROLE_NAME"
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --description "Deploys jasonpanoff.com from GitHub Actions" \
    --assume-role-policy-document "$TRUST" >/dev/null
fi

# 3. Permissions -------------------------------------------------------------
PERMS=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WriteSiteObjects",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    },
    {
      "Sid": "ListBucketForSync",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "InvalidateCache",
      "Effect": "Allow",
      "Action": ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"],
      "Resource": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DISTRIBUTION_ID}"
    }
  ]
}
JSON
)

echo "==> Attaching inline policy $POLICY_NAME"
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "$PERMS"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo
echo "==> Done. Role ARN:"
echo "    $ROLE_ARN"
echo
echo "    Register it with GitHub:"
echo "    gh variable set AWS_ROLE_ARN --body \"$ROLE_ARN\""
