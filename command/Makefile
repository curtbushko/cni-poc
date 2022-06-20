CONSUL_K8S_DIR=$(HOME)/workspace/github.com/hashicorp/feature-cni
MULTUS_DIR=$(HOME)/workspace/github.com/k8snetworkplumbingwg/multus-cni
K8S_GIT_REV=$(shell cd ${CONSUL_K8S_DIR}; git rev-parse --short HEAD)
GIT_COMMIT?=$(shell git rev-parse --short HEAD)
GIT_DIRTY?=$(shell test -n "`git status --porcelain`" && echo "+CHANGES" || true)
GIT_DESCRIBE?=$(shell git describe --tags --always)

gitrev:
	echo "git rev: ${K8S_GIT_REV}"

build: build-installer build-cni
build-installer:
	mkdir -p ./bin
	GOOS=linux GOARCH=amd64 go build -o ./bin/consul-k8s

build-cni:
	cd consul-cni && make build

push-cni:
	docker build -t curtbushko/cni-poc:0.2 .
	docker push curtbushko/cni-poc:0.2

.PHONY: deploy-cni 
deploy-cni:
	kubectl create ns consul
	kubectl apply -f ./deployment -n consul

wait-cni:
	@echo "Waiting for CNI installer to be finished"
	kubectl wait --for=condition=ready --timeout=360s pod -l k8s-app=consul-cni-node -n consul
	@echo "consul-cni-node is ready!"

create: 
	kind create cluster --config=kind.config

delete:
	kind delete cluster

calico: deploy-calico wait-calico

deploy-calico:
	kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
	kubectl apply -f ./calico-config.yaml
	@sleep 20
	kubectl -n calico-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

wait-calico:
	@echo "Waiting for Calico CNI installer to be finished"
	kubectl wait --for=condition=ready --timeout=360s pod -l k8s-app=calico-node -n calico-system 
	@echo "calico-node is ready!"

.PHONY: hashicups
hashicups:
	kubectl apply -f ./hashicups/frontend.yaml -n consul


control-plane: build-control-plane deploy-control-plane

build-control-plane:
	@echo "Building and pushing docker images for control-plane ARM64"
	@cd $(CONSUL_K8S_DIR) && $(CONSUL_K8S_DIR)/control-plane/build-support/scripts/build-local.sh -o linux -a "arm64 amd64"
	cd $(CONSUL_K8S_DIR) && docker buildx build --platform linux/arm64,linux/amd64 -t 'curtbushko/consul-k8s-control-plane-dev:latest' \
        --push \
        --target=dev \
        --build-arg 'GIT_COMMIT=$(GIT_COMMIT)' \
        --build-arg 'GIT_DIRTY=$(GIT_DIRTY)' \
        --build-arg 'GIT_DESCRIBE=$(GIT_DESCRIBE)' \
        -f $(CONSUL_K8S_DIR)/control-plane/Dockerfile $(CONSUL_K8S_DIR)/control-plane

manifest:
	docker manifest create --amend curtbushko/consul-k8s-control-plane-dev:latest \
		curtbushko/consul-k8s-control-plane-dev:latest-arm64 \
		curtbushko/consul-k8s-control-plane-dev:latest-amd64
	docker manifest push curtbushko/consul-k8s-control-plane-dev:latest

deploy-control-plane:
	cd $(CONSUL_K8S_DIR)/charts && helm install consul ./consul \
          --set name=consul \
          --set global.imageK8S="curtbushko/consul-k8s-control-plane-dev:latest" \
	  --set global.loglevel="debug" \
          --set connectInject.enabled=true \
          --set connectInject.default=true \
          --set connectInject.transparentProxy.defaultEnabled=true \
          --set server.replicas=1 \
          --set ui.enabled=true \
          --set controller.enabled=true \
          --create-namespace -n consul

wait-control-plane:
	@echo "Waiting for Consul k8s control-plane to be finished"
	kubectl wait --for=condition=ready --timeout=360s pod -l app=consul -n consul
	@echo "consul control-plane is ready!"

zzz:
	@echo "Sleeping..."
	sleep 30

deploy-multus:
	kubectl apply -f $(MULTUS_DIR)/deployments/multus-daemonset.yml

podstatus:
	kubectl ns consul 
	kubectl get pods 

exec:
	docker exec -it kind-control-plane /bin/bash

all: delete create deploy-calico build docker wait-calico deploy-cni wait-cni hashicups podstatus
deploy: delete create deploy-calico wait-calico deploy-cni wait-cni hashicups podstatus

	
