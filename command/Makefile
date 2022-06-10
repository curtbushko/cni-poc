build: build-installer build-cni
build-installer:
	mkdir -p ./bin
	GOOS=linux GOARCH=amd64 go build -o ./bin/consul-k8s

build-cni:
	cd consul-cni && make build

docker:
	docker build -t curtbushko/cni-poc:0.2 .
	docker push curtbushko/cni-poc:0.2

.PHONY: deploy-cni 
deploy-cni:
	kubectl create ns consul
	kubectl apply -f ./deployment -n consul

create: 
	kind create cluster --config=kind.config

delete:
	kind delete cluster

deploy-calico:
	kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
	kubectl apply -f ./calico-config.yaml
	@sleep 20
	kubectl -n calico-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

.PHONY: hashicups
hashicups:
	kubectl apply -f ./hashicups -n consul

wait-calico:
	@echo "Waiting for Calico CNI installer to be finished"
	kubectl wait --for=condition=ready --timeout=360s pod -l k8s-app=calico-node -n calico-system 
	@echo "calico-node is ready!"

wait-cni:
	@echo "Waiting for CNI installer to be finished"
	kubectl wait --for=condition=ready --timeout=360s pod -l k8s-app=consul-cni-node -n consul
	@echo "consul-cni-node is ready!"

podstatus:
	kubectl ns consul 
	kubectl get pods 

exec:
	docker exec -it kind-control-plane /bin/bash

all: delete create deploy-calico build docker wait-calico deploy-cni wait-cni hashicups podstatus
deploy: delete create deploy-calico wait-calico deploy-cni wait-cni hashicups podstatus

	
