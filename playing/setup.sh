#!/bin/bash

set -e

kind create cluster --config=single-node.yaml

#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
#kubectl apply -f ./calico-config.yaml


#for node in $(kubectl get nodes --selector='node-role.kubernetes.io/master' | awk 'NR>1 {print $1}' ) ; do   kubectl taint node $node node-role.kubernetes.io/master- ; done

# Metrics Server
kubectl config set-context --current --namespace kube-system
helm repo add bitnami https://charts.bitnami.com/bitnami
helm upgrade metrics-server --install -f metrics-server.yaml \
bitnami/metrics-server --namespace kube-system

# Calico
istioctl install -y -f install-istio.yaml
