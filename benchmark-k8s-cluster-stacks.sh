#!/bin/bash

set -e

. ./time.sh

function await() {
  echo "awaiting $1"
  timeout 30 bash -c \
    "until $1 ; do sleep 0.1 ; done "
  time::
}

date
time::start
time minikube start

kubectl get pods -A
await "kubectl get pods -A | grep Running | wc -l | grep 6"
time kubectl create deployment nginx --image nginx
await "kubectl get pods -A | grep nginx | grep Running"

kubectl get pods -A

time minikube delete --all
date
time::
