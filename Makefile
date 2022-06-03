build:
	docker build -t curtbushko/cni-poc:0.1 .
	docker push curtbushko/cni-poc:0.1

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

zzz:
	@echo "Zzzzzz"
	@sleep 30

all: delete build create zzz deploy
	

