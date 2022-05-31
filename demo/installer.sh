#!/bin/sh

CNI_BIN_DIR=/host/opt/cni/bin
CNI_NET_DIR=/host/etc/cni/net.d

echo "Coping /bin/consul-cni to $CNI_BIN_DIR"
cp /bin/consul-cni $CNI_BIN_DIR

echo "Looking at bin files"
ls $CNI_BIN_DIR

echo "Coping config file to $CNI_NET_DIR"
cp /bin/10-kindnet.conflist $CNI_NET_DIR

echo "Looking at net files"
ls $CNI_NET_DIR

echo "Sleeping"
sleep infinity


