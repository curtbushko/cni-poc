VERSION = $(shell ./cni/build-support/scripts/version.sh control-plane/version/version.go)

# ===========> CNI Targets
cni-dev: ## Build cni binaries.
	@cd $(CURDIR)/cni/plugin; GCO_ENABLED=0 go build -o $(CURDIR)/cni/dist/$(PLUGIN_BIN_NAME)

cni-dev-docker: ## Build cni dev Docker image.
	@$(SHELL) $(CURDIR)/cni/build-support/scripts/build-local.sh -o linux -a amd64
	@DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build -t '$(DEV_CNI_IMAGE)' \
       --target=dev \
       --build-arg 'GIT_COMMIT=$(GIT_COMMIT)' \
       --build-arg 'GIT_DIRTY=$(GIT_DIRTY)' \
       --build-arg 'GIT_DESCRIBE=$(GIT_DESCRIBE)' \
       -f $(CURDIR)/cni/Dockerfile $(CURDIR)/cni

cni-test: ## Run go test for cni plugin and installer
	cd $(CURDIR)/cni/plugin; go test ./...

cni-cov: ## Run go test with code coverage.
	cd $(CURDIR)/cni/plugin; go test ./... -coverprofile=coverage.out; go tool cover -html=coverage.out

cni-clean: ## Delete bin dir
	@rm -rf \
		$(CURDIR)/cni/dist 

cni-lint: ## Run linter in the cni directory.
	cd $(CURDIR)/cni/plugin/; golangci-lint run -c ../.golangci.yml

# ===========> Makefile config

PLUGIN_BIN_NAME=consul-cni
INSTALL_BIN_NAME=cni-install
DEV_CNI_IMAGE?=consul-cni-dev
.DEFAULT_GOAL := help
.PHONY: gen-helm-docs copy-crds-to-chart bats-tests help ci.aws-acceptance-test-cleanup version
SHELL = bash
GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)
DEV_IMAGE?=consul-k8s-control-plane-dev
GIT_COMMIT?=$(shell git rev-parse --short HEAD)
GIT_DIRTY?=$(shell test -n "`git status --porcelain`" && echo "+CHANGES" || true)
GIT_DESCRIBE?=$(shell git describe --tags --always)
CRD_OPTIONS ?= "crd:allowDangerousTypes=true"
