#!/bin/bash

set -e

VERBOSE=0
CLEAN=0
BENCHMARK=1
KEEP_CLUSTER=0
TIMING_FILE=/tmp/benchmark-timing.txt

while getopts "ckpt:v" opt; do
  case "$opt" in
    c) CLEAN=1 ; BENCHMARK=0 ;;
    p) CLEAN=1 ;;
    k) KEEP_CLUSTER=1 ;;
    t) TOOL=$OPTARG ;;
    v) VERBOSE=1 ;;
  esac
done

. ./time.sh

echo "k8s-cluster-benchmark" > $TIMING_FILE

function await() {
  [[ $VERBOSE == "1" ]] && echo "awaiting $1"
  timeout 30 bash -c \
    "until $1 ; do sleep 0.1 ; done "
}

function clean() {
  tool=$1
  case $tool in
    minikube) time minikube delete --all ;;
    kind) time kind delete cluster ;;
    k3d) time k3d cluster delete my-cluster ;;
  esac
}

function benchmark() {
  tool=$1
  time::start
  date
  time:: "$tool : start" | tee -a $TIMING_FILE
  case $tool in 
    minikube) time minikube start ;;
    kind) time kind -q -v $VERBOSE create cluster ;;
    k3d) time k3d cluster create my-cluster --k3s-arg '--disable=traefik@server:*' ;;
  esac
  time:: "$tool : after create" | tee -a $TIMING_FILE

  case $tool in 
    minikube) await "kubectl get pods -A | grep Running | wc -l | grep 6" ;;
    kind) await "kubectl get pods -A | grep Running | wc -l | grep 9" ;;
    k3d) await "kubectl get pods -A | grep Running | wc -l | grep 5" ;;
  esac
  time:: "$tool : after running" | tee -a $TIMING_FILE
  time kubectl create deployment nginx --image nginx
  await "kubectl get pods -A | grep nginx | grep Running"
  time:: "$tool : after deploy" | tee -a $TIMING_FILE

  [[ $VERBOSE == "1" ]] && kubectl get pods -A

  [[ $KEEP_CLUSTER == "0" ]] && clean $tool
  date
  time:: "$tool : after clean" | tee -a $TIMING_FILE
}

if [[ -n $TOOL ]] ; then
  [[ "$CLEAN" == "1" ]] && clean $TOOL
  [[ "$BENCHMARK" == "1" ]] && benchmark $TOOL
else
  for t in minikube kind k3d ; do 
    [[ "$CLEAN" == "1" ]] && clean $t
    [[ "$BENCHMARK" == "1" ]] && benchmark $t
  done
fi

cat $TIMING_FILE
