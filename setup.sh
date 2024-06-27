#!/bin/sh
set -e

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Setup for the Compositions chapter'

gum confirm '
Are you ready to start?
Select "Yes" only if you did NOT follow the story from the start (if you jumped straight into this chapter).
Feel free to say "No" and inspect the script if you prefer setting up resources manually.
' || exit 0

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|Linux Shell     |Yes                  |Use WSL if you are running Windows                 |
|Docker          |Yes                  |'https://docs.docker.com/engine/install'           |
|kind CLI        |Yes                  |'https://kind.sigs.k8s.io/docs/user/quick-start/#installation'|
|kubectl CLI     |Yes                  |'https://kubernetes.io/docs/tasks/tools/#kubectl'  |
|crossplane CLI  |Yes                  |'https://docs.crossplane.io/latest/cli'            |
|yq CLI          |Yes                  |'https://github.com/mikefarah/yq#install'          |
|AWS account with admin permissions|If using AWS|'https://aws.amazon.com'                  |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker** and the **hyperscaler account**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0


#########################
# Control Plane Cluster #
#########################

kind create cluster --config kind.yaml

kubectl create namespace a-team

##############
# Crossplane #
##############

helm upgrade --install crossplane crossplane \
    --repo https://charts.crossplane.io/stable \
    --namespace crossplane-system --create-namespace --wait

HYPERSCALER="AWS"
echo "export HYPERSCALER=AWS" >> .env

AWS_ACCESS_KEY_ID=$(gum input --placeholder "AWS Access Key ID" --value "$AWS_ACCESS_KEY_ID")
echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> .env

AWS_SECRET_ACCESS_KEY=$(gum input --placeholder "AWS Secret Access Key" --value "$AWS_SECRET_ACCESS_KEY" --password)
echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> .env

AWS_ACCOUNT_ID=$(gum input --placeholder "AWS Account ID" --value "$AWS_ACCOUNT_ID")
echo "export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" >> .env

echo "[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
" >aws-creds.conf