#!/bin/bash
set -e

# Variables (replace these with your values)
ROLE_ARN="arn:aws:iam::851725299431:role/tkp/TKPSandboxEngineer"  # The role ARN to assume
SESSION_NAME="my-session"  # The session name for STS
NAMESPACE="crossplane-system"  # The Kubernetes namespace
SECRET_NAME="aws-creds"  # The secret name in Kubernetes

# Assume the IAM role
ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "$SESSION_NAME" \
  --duration-seconds 3600 \
  --output json)

# Extract the credentials from the response
AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .Credentials.AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .Credentials.SecretAccessKey)
AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .Credentials.SessionToken)

export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN

# Create the AWS credentials file content
AWS_CREDS_CONTENT="[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token = $AWS_SESSION_TOKEN
"

# Create or update the Kubernetes secret
kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=creds="$AWS_CREDS_CONTENT" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Kubernetes secret '$SECRET_NAME' created/updated in namespace '$NAMESPACE'."

kubectl get pods -n crossplane-system --no-headers | grep provider-aws | awk '{print $1}' | xargs kubectl delete pod -n crossplane-system
