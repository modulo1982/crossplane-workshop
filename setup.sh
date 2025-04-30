#!/bin/sh
set -e

#########################
# Control Plane Cluster #
#########################

kind create cluster --name crossplane-workshop

##############
# Crossplane #
##############

helm upgrade --install crossplane crossplane \
    --repo https://charts.crossplane.io/stable \
    --namespace crossplane-system --create-namespace --wait