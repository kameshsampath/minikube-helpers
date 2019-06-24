#!/bin/bash 

set -eu

set -o pipefail 

eval $(minikube docker-env )

IMAGES=$(minikube ssh -- sudo podman images | grep -v 'sha256' | tail -n +2 | awk '{print $1":"$2}')
IMAGES=$(docker images | grep -v 'sha256' | tail -n +2 | awk '{print $1":"$2}')

IFS=$'\n'

for img in $IMAGES 
do
  echo "Adding $img to cache"
  minikube cache add "$img" || true
done

## Extra  images
minikube cache add quay.io/rhdevelopers/quarkus-java-builder || true
minikube cache add fabric8/java-jboss-openjdk8-jdk:1.5.4 || true
minikube cache add fabric8/java-jboss-openjdk8-jdk:1.5.2 || true
minikube cache add registry.fedoraproject.org/fedora-minimal || true
minikube cache add quay.io/rhdevelopers/tutorial-tools || true