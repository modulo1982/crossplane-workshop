#!/bin/bash
set -e

export AWS_CONFIG_FILE=$(pwd)/awsconfig.ini
ASSUME_ROLE_OUTPUT=$(aws-vault exec workshop-sandbox-2 --json)

# Extract the credentials from the response
AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .SecretAccessKey)
AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .SessionToken)

# Create the AWS credentials file content
AWS_CREDS_CONTENT="[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token = $AWS_SESSION_TOKEN
"

# Create or update the Kubernetes secret
kubectl create secret generic aws-creds \
  --namespace crossplane-system \
  --from-literal=creds="$AWS_CREDS_CONTENT" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Kubernetes secret aws-creds created/updated in namespace crossplane-system."

kubectl get pods -n crossplane-system --no-headers | grep provider-aws | awk '{print $1}' | xargs kubectl delete pod -n crossplane-system
