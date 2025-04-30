
########################
# Setup NIX environment
########################
    
    nix-shell --run $SHELL
    chmod +x setup.sh setup-creds.sh
    ./setup.sh
    ./setup-creds.sh

Test that everything works:

    aws-vault exec workshop-sandbox-2 --
    aws lambda list-functions
    docker ps
    kubectl get pods -n crossplane-system
    kubens crossplane-system

Controller het secret:

    kubectl get secret aws-creds -o json | jq -r .data.creds | base64 -d
    
Zou een output moeten laten zien als:

    [default]
    aws_access_key_id = ASIA4MTWIV3T2IAQZWTT
    aws_secret_access_key = heel-geheim-token
    aws_session_token = heel-lang-token


########################
# Crossplane Providers #
########################

Lets replace timo-workshop with $USER-workshop for all example files.

    find . -type f \( -name '*.yaml' -o -name '*.md' \) -exec sed -i '' "s/timo-workshop/${USER}-workshop/g" {} +

Install the provider for AWS.

    cat providers/aws-s3.yaml
    kubectl apply --filename providers/aws-s3.yaml
    kubectl get pkgrev

Learn about Providers and ProviderFamilies.

    kubectl wait --for=condition=healthy --timeout=240s provider/upbound-provider-family-aws
    kubectl wait --for=condition=healthy --timeout=240s provider/provider-aws-s3
    kubectl get crd | grep upbound.io

# Step 1 Basic Managed Resource

    cd step1

## 1a - Install some managed resources

    cat 1a.yaml
    kubectl apply -f 1a.yaml
    kubectl get managed

Check the logs of the provider pods.
Check the status of the managed objects.
Check the events

    kubectl get events -n default
    kubectl get bucket.s3.aws.upbound.io/timo-workshop-bucket -o json | jq .status

Perform the final configuration of the provider

    cat ../providers/aws-config.yaml
    kubectl apply --filename ../providers/aws-config.yaml

    ../setups-creds.sh
    kubectl get secret aws-creds -n crossplane-system -o jsonpath='{.data.creds}' | base64 --decode
    
    kubectl get managed

Learn about how crossplane reconciles managed resources. See how native kubernetes concepts, spec, status and events
are used. Take a look at spec.status.atProvider.

Check the logs of the provider pods.

So the main takeaway here is that you describe your desired state in the spec.atProvider section and the actual state is
represented by spec.status.atProvider. As long as nothing is inherently wrong these should be pretty much the same.

## 1b - Modify a resource

    diff 1a.yaml 1b.yaml
    cat 1b.yaml
    kubectl apply --filename 1b.yaml
    kubectl get managed

You can control how Crossplane interacts through management policies. That that is an advanced topic.

https://docs.crossplane.io/latest/concepts/managed-resources


#####################################
# Step 2 Multiple managed resources #
#####################################

    cd ..
    cd step2

## 2a - Add LifecyclePolicy to Bucket

    cat 2a.yaml
    kubectl apply -f 2a.yaml

## 2b - Making a Lambda Function

Lets make it more interesting by making a Lambda function.

Copy files to S3 bucket:

    aws s3 cp ../jokes/jokes_function.zip s3://timo-workshop-bucket/                                                                                                                                  │
    aws s3 cp ../jokes/jokes.txt s3://timo-workshop-bucket/

Apply Lambda and Role

    cat 2b.yaml
    kubectl apply -f 2b.yaml

Kak!

    kubectl apply -f ../providers/aws-lambda.yaml
    kubectl apply -f ../providers/aws-iam.yaml

    kubectl apply -f 2b.yaml
    kubectl get managed

Invoke the Lambda function:

    aws lambda invoke --function-name timo-workshop-lambda  --output text /dev/stdout
    aws lambda invoke --function-name timo-workshop-lambda --query 'Payload' --output text /dev/stdout | jq

## Step 2c

Use a label to attach the LifecyclePolicy to the bucket

    kubectl delete -f 2a.yaml
    diff 2a.yaml 2c.yaml
    kubectl apply -f 2c.yaml
    kubectl get managed

## Step 2d

Now as an exercise please do the same to the Lambda function and the role.

    cp 2b.yaml 2d.yaml
    kubectl delete -f 2b.yaml

Make your changes in `2d.yaml` and:

    kubectl apply -f 2d.yaml

Lets talk building blocks.

## Delete Managed Resources

    kubectl delete -f 2a.yaml -f 2b.yaml

Now we now *everything there is to know* about managed resources and providers lets dive into XRD's and Composites
and Claims.

# Step 3 Lets make some compositions

    cd step3

## Step 3a - Trying to create a Custom Object

    kubectl apply -f 3a.yaml

## Step 3b - Adding the CRD / XRD

    kubectl apply -f 3b.yaml
    kubectl get bucket.workshop.tkp.nl

## Step 3c - Basic implementation (KCL)

    kubectl apply -f 3c.yaml
    kubectl get function.pkg.crossplane.io -n crossplane-system
    kubectl get pod -n crossplane-system
    kubectl describe bucket.workshop.tkp.nl
    kubectl get managed
    kubectl get bucket.workshop.tkp.nl

## Step 3d - Auto Ready

    diff 3c.yaml 3d.yaml

    kubectl apply -f 3d.yaml
    kubectl get function.pkg.crossplane.io -n crossplane-system
    kubectl get pod -n crossplane-system
    kubectl get bucket.workshop.tkp.nl

## Step 3e - Controller Reference

    diff 3d.yaml 3e.yaml
    kubectl apply -f 3e.yaml
    kubectl get bucket.workshop.tkp.nl

Make sure the managed resources are generated by our composition

    kubectl delete -f 3a.yaml
    kubectl get managed
    kubectl apply -f 3a.yaml

    kubectl get bucketversioning.s3.aws.upbound.io/timo-workshop-bucket-versioning -o json | jq .status.atProvider

## Step 3f - Environment Config

    diff 3e.yaml 3f.yaml
    kubectl apply -f 3f.yaml

## Step 3g - Creating the Claim

    crossplane beta trace bucket.workshop.tkp.nl/timo-workshop-bucket
    diff 3f.yaml 3g.yaml

    kubectl delete -f 3a.yaml
    kubectl apply -f 3g.yaml

    crossplane beta trace bucketclaim.workshop.tkp.nl/timo-workshop-bucket

#  Step 4 Now try the same for Role and Lambda

## What do we want to expose as an API?

    cat 4a.yaml

Now try to write the API by extending 4b.yaml 

    cat 4b.yaml
    kubectl apply -f 4b.yaml
    kubectl apply -f 4a.yaml

If you want to cheat look at what I fabricated:

    cat 4c.yaml

## Now try to create an implementation

    cat 4d.yaml
    kubectl apply -f 4d.yaml
    kubectl delete -f 4a.yaml
    kubectl apply -f 4a.yaml

This method of developing sucks, we can use crossplane render to help us:
https://blog.upbound.io/composition-testing-patterns-rendering

    crossplane render resource.yaml composition.yaml functions.yaml --extra-resources extra-resources.yaml

# Review of crossplane-claims project

Code completion
Shared constructs
Unit testing
Chainsaw testing

######################
# Destroy Everything #
######################

    remove all claims
    remove all composites
    remove all maanged resources
    remove kind cluster
    exit