build:
	docker build -t curtbushko/cni-poc:latest .
	docker push curtbushko/cni-poc:latest

deploy:
	kubectl create ns consul
	kubectl apply -f ./deployment -n consul

create: 
	kind create cluster

delete:
	kind delete cluster

zzz:
	@echo "Zzzzzz"
	@sleep 30

all: delete build create zzz deploy
	

