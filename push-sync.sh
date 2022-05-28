#!/bin/bash
DEST=${HOME}/workspace/github.com/hashicorp/feature-cni/control-plane
SRC=${HOME}/workspace/github.com/curtbushko/cni-poc

mkdir -p "${DEST}/subcommand/cni-install"
mkdir -p "${DEST}/cni"
#mkdir -p "${DEST}/connect-inject"

rsync -a "${SRC}/cni" "${DEST}"
#rsync -a "${SRC}/control-plane/connect-inject" "${DEST}"
rsync "${SRC}/Dockerfile" "${DEST}"
rsync "${SRC}/Makefile" "${DEST}"
rsync "${SRC}/go.mod" "${DEST}"
rsync "${SRC}/go.sum" "${DEST}"
rsync -a "${SRC}/subcommand/cni-install" "${DEST}/subcommand/cni-install"

