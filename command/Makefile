build:
	mkdir -p ./bin
	GOOS=linux GOARCH=amd64 go build -o ./bin/consul-k8s
	cp ~/workspace/github.com/hashicorp/feature-cni/control-plane/cni/bin/consul-cni ./bin

docker:
	docker build -t curtbushko/cni-poc:0.2 .
	docker push curtbushko/cni-poc:0.2

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

podstatus:
	kubectl ns consul 
	kubectl get pods 

all: delete create build docker deploy podstatus
	

