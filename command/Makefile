build:
	mkdir -p ./bin
	GOOS=linux GOARCH=amd64 go build -o ./bin/consul-k8s

cni:
	cd consul-cni && make build

docker:
	docker build -t curtbushko/cni-poc:0.2 .
	docker push curtbushko/cni-poc:0.2

.PHONY: cni 
deploy:
	kubectl create ns consul
	kubectl apply -f ./deployment -n consul

create: 
	kind create cluster --config=kind.config

delete:
	kind delete cluster

calico:
	kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
	kubectl apply -f ./calico-config.yaml
	@sleep 20
	kubectl -n calico-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

.PHONY: hashicups
hashicups:
	kubectl apply -f ./hashicups -n consul

zzz:
	@echo "Zzzzzz"
	@sleep 20

podstatus:
	kubectl ns consul 
	kubectl get pods 

exec:
	docker exec -it kind-control-plane /bin/bash

all: delete create calico build cni docker zzz deploy zzz hashicups podstatus
	
