#!/bin/bash
DEST=${HOME}/workspace/github.com/hashicorp/feature-cni
SRC=${HOME}/workspace/github.com/curtbushko/cni-poc

mkdir -p "${DEST}/subcommand"
#mkdir -p "${DEST}/connect-inject"

rsync -a "${SRC}/control-plane/cni" "${DEST}"
#rsync -a "${SRC}/control-plane/connect-inject" "${DEST}"
rsync "${SRC}/control-plane/Dockerfile" "${DEST}"
rsync "${SRC}/control-plane/Makefile" "${DEST}"
rsync "${SRC}/control-plane/go.mod" "${DEST}"
rsync "${SRC}/control-plane/go.sum" "${DEST}"
rsync -a "${SRC}/control-plane/subcommand/cni-install" "${DEST}/subcommand/cni-install"

