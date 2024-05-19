#!/bin/bash

set -e

function await() {
  timeout 30 bash -c \
    "until $1 ; do sleep 0.1 ; done "
}

. ./time.sh

date
time::start
time minikube start
time::

kubectl get pods -A
time kubectl create deployment nginx --image nginx
time await "kubectl get pods -A | grep nginx | grep Running"

kubectl get pods -A

time minikube delete --all
date
time::
