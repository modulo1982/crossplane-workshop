
########################
# Setup NIX environment
########################
    
    nix-shell --run $SHELL
    chmod +x setup.sh
    ./setup.sh
    source .env

Test that everything works:

    aws iam list-users
    docker ps
    kubectl get all -A

########################
# Crossplane Providers #
########################

Install the provider for AWS.

    cat providers/aws-vm.yaml
    kubectl apply --filename providers/aws-vm.yaml
    kubectl get pkgrev

Repeat the command until all providers are healthy.
Learn about Providers and ProviderFamilies.

    kubectl get pkgrev
    kubectl get crds

############################
# Create Managed Resources #
############################

Install some managed resources

    cat examples/aws-vm.yaml

    kubectl apply --filename examples/aws-vm.yaml
    kubectl get managed

Check the status of the managed objects.
Check the logs of the provider pods.

Perform the final configuration of the provider

    kubectl --namespace crossplane-system create secret generic aws-creds --from-file creds=./aws-creds.conf

    cat providers/aws-config.yaml
    kubectl apply --filename providers/aws-config.yaml
    
    kubectl get managed

Learn about how crossplane reconciles managed resources. See how native kubernetes concepts, spec, status and events
are used. Take a look at spec.status.atProvider.

Check the logs of the provider pods.

############################
# Update Managed Resources #
############################

    kubectl get instance.ec2.aws.upbound.io/my-vm -o yaml

    diff examples/aws-vm.yaml examples/aws-vm-bigger.yaml

    kubectl apply --filename examples/aws-vm-bigger.yaml

See how crossplane ensures the requested state is reconciled on your provider. Imagine how this works in terraform?

############################
# Delete Managed Resources #
############################

Please make sure I don't get billed too much for this!

    kubectl delete --filename examples/aws-vm-bigger.yaml

Now we now *everything there is to know* about managed resources and providers lets dive into XRD's and Composites
and Claims.

##################################
# Composite Resource Definitions #
##################################

    cat compositions/sql-v1/definition.yaml
    kubectl apply --filename compositions/sql-v1/definition.yaml
    kubectl get compositeresourcedefinitions
    kubectl get xrds
    kubectl get crds | grep sql
    kubectl explain sqls.devopstoolkitseries.com --recursive

Learn about XRD's
Learn about CRD's

    cat examples/$HYPERSCALER-sql-v1.yaml
    kubectl apply --filename examples/$HYPERSCALER-sql-v1.yaml
    kubectl get sqls
    kubectl get managed
    kubectl get compositions

As you can see the above has no effect.


#########################
# Defining Compositions #
#########################

    cat compositions/sql-v1/$HYPERSCALER.yaml
    ls -1 compositions/sql-v1
    kubectl apply --filename compositions/sql-v1

Now lets see what is going on, i.e.:

    kubectl get managed

Any other commands?

    crossplane beta trace sql my-db

So lets fix it:

    cat providers/sql-v1.yaml
    kubectl apply --filename providers/sql-v1.yaml
    kubectl get pkgrev
    
    crossplane beta trace sql my-db
    crossplane beta trace sql my-db

#####################################
# Resource References and Selectors #
#####################################

Learn a bit about resource references: https://docs.crossplane.io/latest/concepts/compositions/#cross-resource-references

    cat compositions/sql-v1/$HYPERSCALER.yaml
    cat compositions/sql-v2/$HYPERSCALER.yaml
    kubectl apply --filename compositions/sql-v2

Delete the composition and watch the process

    kubectl delete --filename examples/$HYPERSCALER-sql-v1.yaml
    kubectl get managed

############
# Patching #
############

Learn a bit about patching and transforming: https://docs.crossplane.io/latest/concepts/patch-and-transform/

Check the XRD, we see two new fields id and parameters. Parameters has two additional fields version and size.

    cat compositions/sql-v3/definition.yaml
    kubectl apply --filename compositions/sql-v3/definition.yaml

How would we use this?

    cat examples/$HYPERSCALER-sql-v3.yaml
    cat compositions/sql-v3/$HYPERSCALER.yaml

    kubectl apply --filename compositions/sql-v3
    kubectl apply --filename examples/$HYPERSCALER-sql-v3.yaml

    crossplane beta trace sql my-db


###############################
# Managing Connection Secrets #
###############################

Learn a bit abount connection details: https://docs.crossplane.io/latest/concepts/connection-details/
Configure crossplane to create the secret

    cat compositions/sql-v4/$HYPERSCALER.yaml
    kubectl apply --filename compositions/sql-v4
    kubectl --namespace crossplane-system get secrets

    export DB=my-db
    kubectl --namespace crossplane-system get secret $DB --output yaml


#######################################
# Combining Providers in Compositions #
#######################################

    export PGUSER=$(kubectl --namespace crossplane-system \
    get secret $DB --output jsonpath="{.data.username}" \
    | base64 -d)
    
    export PGPASSWORD=$(kubectl --namespace crossplane-system \
    get secret $DB --output jsonpath="{.data.password}" \
    | base64 -d)
    
    export PGHOST=$(kubectl --namespace crossplane-system \
    get secret $DB --output jsonpath="{.data.host}" \
    | base64 -d)
    
    echo "Connection details:\n PGUSER: $PGUSER\n PGPASSWORD: $PGPASSWORD\n PGHOST: $PGHOST"
    
So now we retrieved all the connection details, lets try to connect to the database:

    kubectl run postgresql-client --rm -ti --restart='Never' \
    --image docker.io/bitnami/postgresql:16 \
    --env PGPASSWORD=$PGPASSWORD --env PGHOST=$PGHOST \
    --env PGUSER=$PGUSER --command -- sh
    
    psql --host $PGHOST -U $PGUSER -d postgres -p 5432
    
    \l
    
    exit
    
    exit


################################
# Create a Postgresql database #
################################

We want to create a Database within the rdsInstance. So what do we need?

We need to configure the providers:

    kubectl get pkgrev
    cat providers/sql-v5.yaml
    kubectl apply --filename providers/sql-v5.yaml

    kubectl get pkgrev

    cat compositions/sql-v5/$HYPERSCALER.yaml
    kubectl apply --filename compositions/sql-v5
    crossplane beta trace sql my-db

Connect to the database again and list the databases

    kubectl run postgresql-client --rm -ti --restart='Never' \
    --image docker.io/bitnami/postgresql:16 \
    --env PGPASSWORD=$PGPASSWORD --env PGHOST=$PGHOST \
    --env PGUSER=$PGUSER --command -- sh
    
    psql --host $PGHOST -U $PGUSER -d postgres -p 5432
    
    \l
    
    exit
    
    exit

Clean up:

    kubectl delete --filename examples/$HYPERSCALER-sql-v3.yaml
    
    kubectl get managed
    
    kubectl patch database.postgresql.sql.crossplane.io $DB --patch '{"metadata":{"finalizers":[]}}' --type=merge


#############################
# Defining Composite Claims #
#############################

    cat compositions/sql-v5/definition.yaml
    cat compositions/sql-v6/$HYPERSCALER.yaml
    kubectl apply --filename compositions/sql-v6
    cat examples/$HYPERSCALER-sql-v6.yaml
    kubectl --namespace a-team apply --filename examples/$HYPERSCALER-sql-v6.yaml

Let's check it out:

    kubectl --namespace a-team get sqlclaims
    crossplane beta trace sqlclaim my-db --namespace a-team
    kubectl --namespace a-team get secrets

######################
# Destroy Everything #
######################

    kubectl delete --namespace a-team sqlclaim/my-db 
    kubectl get managed
    kubectl patch database.postgresql.sql.crossplane.io $DB --patch '{"metadata":{"finalizers":[]}}' --type=merge
    exit