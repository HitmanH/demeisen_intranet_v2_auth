#!/usr/bin/env bash
# Adopts the existing Demeisen user pool and its sign-in domain into the stack demeisen-v2-auth-pool, without
# touching the users. Run in AWS CloudShell, once, AFTER the v1 CRM stack no longer holds the pool (see the
# cut-over runbook in demeisen_intranet_v2_platform/ops/RUNBOOK.md, step "Release the pool from v1").
#   ./pool/import.sh [pool-id] [domain-prefix]
set -euo pipefail
POOL="${1:-eu-west-2_o84PDILyl}"; DOMAIN="${2:-demeisen-crm-poc}"; STACK=demeisen-v2-auth-pool
REGION="${AWS_REGION:-eu-west-2}"; here="$(cd "$(dirname "$0")" && pwd)"
export AWS_REGION="$REGION"

if aws cloudformation describe-stacks --stack-name "$STACK" >/dev/null 2>&1; then
  echo "$STACK already exists; nothing to import."; exit 0
fi
# The pool must no longer belong to another stack.
owner=$(aws cloudformation describe-stack-resources --physical-resource-id "$POOL" --query 'StackResources[0].StackName' --output text 2>/dev/null || true)
if [ -n "$owner" ] && [ "$owner" != "None" ]; then
  echo "The pool still belongs to stack $owner. Release it from that stack first (runbook)."; exit 1
fi
SITE=$(aws ssm get-parameter --name /demeisen/v2/edge/url --query Parameter.Value --output text 2>/dev/null || echo 'https://example.invalid/')

aws cloudformation create-change-set --stack-name "$STACK" --change-set-name import-pool --change-set-type IMPORT \
  --template-body "file://$here/demeisen-pool.yaml" \
  --parameters ParameterKey=PoolName,ParameterValue="$(aws cognito-idp describe-user-pool --user-pool-id "$POOL" --query UserPool.Name --output text)" \
               ParameterKey=DomainPrefix,ParameterValue="$DOMAIN" ParameterKey=SiteUrl,ParameterValue="$SITE" \
  --resources-to-import "[{\"ResourceType\":\"AWS::Cognito::UserPool\",\"LogicalResourceId\":\"UserPool\",\"ResourceIdentifier\":{\"UserPoolId\":\"$POOL\"}},
                          {\"ResourceType\":\"AWS::Cognito::UserPoolDomain\",\"LogicalResourceId\":\"UserPoolDomain\",\"ResourceIdentifier\":{\"UserPoolId\":\"$POOL\",\"Domain\":\"$DOMAIN\"}}]"
aws cloudformation wait change-set-create-complete --stack-name "$STACK" --change-set-name import-pool
aws cloudformation describe-change-set --stack-name "$STACK" --change-set-name import-pool --query 'Changes[].ResourceChange.[Action,LogicalResourceId,PhysicalResourceId]' --output table
read -r -p "Import these into $STACK? [y/N] " ok; [ "$ok" = y ] || { echo "Stopped; nothing changed."; exit 1; }
aws cloudformation execute-change-set --stack-name "$STACK" --change-set-name import-pool
aws cloudformation wait stack-import-complete --stack-name "$STACK"
aws cloudformation set-stack-policy --stack-name "$STACK" --stack-policy-body "file://$here/stack-policy.json"
aws cloudformation update-termination-protection --stack-name "$STACK" --enable-termination-protection
echo "Imported. Next: apply the template's settings (deletion protection on) with the 'Deploy pool' workflow."
