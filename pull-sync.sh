#!/bin/bash
SRC=${HOME}/workspace/github.com/hashicorp/feature-cni
DEST=${HOME}/workspace/github.com/curtbushko/cni-poc/consul-k8s

mkdir -p "${DEST}/cni"
mkdir -p "${DEST}/subcommand"
mkdir -p "${DEST}/build-support/scripts"
#mkdir -p "${DEST}/connect-inject"

rsync -a "${SRC}/control-plane/cni" "${DEST}"
rsync "${SRC}/control-plane/Dockerfile" "${DEST}"
rsync "${SRC}/control-plane/Makefile" "${DEST}"
rsync "${SRC}/control-plane/go.mod" "${DEST}"
rsync "${SRC}/control-plane/go.sum" "${DEST}"
rsync "${SRC}/control-plane/commands.go" "${DEST}"
rsync -a "${SRC}/control-plane/subcommand/cni-install" "${DEST}/subcommand/cni-install"
rsync -a "${SRC}/control-plane/build-support/scripts/build-local.sh" "${DEST}/build-support/scripts"

