#!/usr/bin/env bash

KIND_VERSION=v0.12.0
KUBECTL_VERSION=v1.21.0
HELM_VERSION=v3.7.2
ISTIOCTL_VERSION=1.13.3
CONSUL_VERSION=0.43.0

install(){
  sudo curl -s -Lo "/usr/local/bin/$1" "$2"
  sudo chmod +x "/usr/local/bin/$1"
}

install_tgz(){
  curl -s -Lo "$1" "$2"
  sudo tar xf "$1" "$4" -C "/usr/local/bin/" "$3"
  rm -rf "$1"
}

install_kind_cli() {
  if ! [ -x "$(command -v kind)" ]; then
    if [[ "${OSTYPE}" == "linux-gnu" ]]; then
      echo 'kind not found, installing'
      install "kind" "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64"
    else
      echo "Missing required binary in path: kind"
      return 2
    fi
  fi
  local kind_installed_version
  kind_installed_version="v$(kind version -q)"
  if [[ "${KIND_VERSION}" != $(echo -e "${KIND_VERSION}\n${kind_installed_version}" | sort -s -t. -k 1,1n -k 2,2n -k 3,3n | head -n1) ]]; then
    cat <<EOF
Detected kind version: ${kind_installed_version}.
Requires ${KIND_VERSION} or greater.
Updating kind...
EOF
    install "kind" "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64"
  fi
}

install_kubectl_cli() {
  if ! [ -x "$(command -v kubectl)" ]; then
    if [[ "${OSTYPE}" == "linux-gnu" ]]; then
      echo 'kubectl not found, installing'
      install "kubectl" "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    else
      echo "Missing required binary in path: kubectl"
      return 2
    fi
  fi
  local kubectl_installed_version
  IFS=" " read -ra kubectl_installed_version <<< "$(kubectl version --client --short)"
  if [[ "${KUBECTL_VERSION}" != $(echo -e "${KUBECTL_VERSION}\n${kubectl_installed_version[2]}" | sort -s -t. -k 1,1 -k 2,2n -k 3,3n | head -n1) ]]; then
    cat <<EOF
Detected kubectl version: ${kubectl_installed_version}.
Requires ${KUBECTL_VERSION} or greater.
Updating kubectl...
EOF
    install "kubectl" "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  fi
}

install_kustomize_cli() {
  if ! [ -x "$(command -v kustomize)" ]; then
    if [[ "${OSTYPE}" == "linux-gnu" ]]; then
      echo 'kustomize not found, installing'
      curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
      sudo mv kustomize /usr/local/bin/kustomize
    else
      echo "Missing required binary in path: kustomize"
      return 2
    fi
  fi
}

install_helm_cli() {
  if ! [ -x "$(command -v helm)" ]; then
    if [[ "${OSTYPE}" == "linux-gnu" ]]; then
      echo 'helm not found, installing'
      install_tgz "helm-${HELM_VERSION}-linux-amd64.tar.gz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" "linux-amd64/helm" "--strip-components=1"
    else
      echo "Missing required binary in path: helm"
      return 2
    fi
  fi
  local helm_installed_version
  helm_installed_version="$(helm version --short | cut -c -6)"
  if [[ "${HELM_VERSION}" != $(echo -e "${HELM_VERSION}\n${helm_installed_version}" | sort -s -t. -k 1,1n -k 2,2n -k 3,3n | head -n1) ]]; then
    cat <<EOF
Detected helm version: ${helm_installed_version}.
Requires ${HELM_VERSION} or greater.
Updating helm...
EOF
    install_tgz "helm-${HELM_VERSION}-linux-amd64.tar.gz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" "linux-amd64/helm" "--strip-components=1"
  fi
}

install_istioctl_cli() {
  if ! [ -x "$(command -v istioctl)" ]; then
    if [[ "${OSTYPE}" == "linux-gnu" ]]; then
      echo 'istioctl not found, installing'
      install_tgz "istioctl-${ISTIOCTL_VERSION}-linux-amd64.tar.gz" "https://github.com/istio/istio/releases/download/${ISTIOCTL_VERSION}/istioctl-${ISTIOCTL_VERSION}-linux-amd64.tar.gz" "istioctl"
    else
      echo "Missing required binary in path: istioctl"
      return 2
    fi
  fi
  local istoctl_installed_version
  istoctl_installed_version="$(istioctl version --short)"
  if [[ "${ISTIOCTL_VERSION}" != $(echo -e "${ISTIOCTL_VERSION}\n${istoctl_installed_version}" | sort -s -t. -k 1,1n -k 2,2n -k 3,3n | head -n1) ]]; then
    cat <<EOF
Detected istioctl version: ${istoctl_installed_version}.
Requires ${ISTIOCTL_VERSION} or greater.
Updating istioctl...
EOF
    install_tgz "istioctl-${ISTIOCTL_VERSION}-linux-amd64.tar.gz" "https://github.com/istio/istio/releases/download/${ISTIOCTL_VERSION}/istioctl-${ISTIOCTL_VERSION}-linux-amd64.tar.gz" "istioctl"
  fi
}

install_j2_renderer() {
  pip3 freeze | grep j2cli || pip3 install j2cli[yaml] --user
  export PATH=~/.local/bin:$PATH
}

run_kubectl() {
  local retries=0
  local attempts=60
  while true; do
    if kubectl "$@"; then
      break
    fi

    ((retries += 1))
    if [[ "${retries}" -gt ${attempts} ]]; then
      echo "error: 'kubectl $*' did not succeed, failing"
      exit 1
    fi
    echo "info: waiting for 'kubectl $*' to succeed..."
    sleep 1
  done
}

usage() {
    echo "usage: kind.sh [--name <cluster-name>]"
    echo "               [--num-workers <num>]"
    echo "               [--config-file <file>]"
    echo "               [--kubernetes-version <num>]"
    echo "               [--cluster-apiaddress <num>]"
    echo "               [--cluster-apiport <num>]"
    echo "               [--cluster-loglevel <num>]"
    echo "               [--cluster-podsubnet <num>]"
    echo "               [--cluster-svcsubnet <num>]"
    echo "               [--disable-default-cni]"
    echo "               [--install-calico-cni]"
    echo "               [--install-cilium-cni]"
    echo "               [--install-multus-cni]"
    echo "               [--install-consul]"
    echo "               [--install-istio]"
    echo "               [--install-metallb]"
    echo "               [--install-nginx-ingress]"
    echo "               [--install-contour-ingress]"
    echo "               [--install-haproxy-ingress]"
    echo "               [--install-istio-gateway-api]"
    echo "               [--install-contour-gateway-api]"
    echo "               [--install-olm]"
    echo "               [--help]"
    echo ""
    echo "--name                          Name of the KIND cluster"
    echo "                                DEFAULT: kind"
    echo "--num-workers                   Number of worker nodes."
    echo "                                DEFAULT: 0 worker nodes."
    echo "--config-file                   Name of the KIND J2 configuration file."
    echo "                                DEFAULT: ./kind.yaml.j2"
    echo "--kubernetes-version            Flag to specify the Kubernetes version."
    echo "                                DEFAULT: Kubernetes v1.21.1"
    echo "--cluster-apiaddress            Kubernetes API IP address for kind (master)."
    echo "                                DEFAULT: 0.0.0.0."
    echo "--cluster-apiport               Kubernetes API port for kind (master)."
    echo "                                DEFAULT: 6443."
    echo "--cluster-loglevel              Log level for kind (master)."
    echo "                                DEFAULT: 4."
    echo "--cluster-podsubnet             Pod subnet IP address range."
    echo "                                DEFAULT: 10.128.0.0/14."
    echo "--cluster-svcsubnet             Service subnet IP address range."
    echo "                                DEFAULT: 172.30.0.0/16."
    echo "--disable-default-cni           Flag to disable Kind default CNI - required to install custom cni plugin."
    echo "                                DEFAULT: Default CNI used."
    echo "--install-calico-cni            Flag to install Calico CNI Components."
    echo "                                DEFAULT: Don't install calico cni components."
    echo "--install-cilium-cni            Flag to install Cilium CNI Components."
    echo "                                DEFAULT: Don't install cilium cni components."
    echo "--install-multus-cni            Flag to install Multus CNI Components."
    echo "                                DEFAULT: Don't install multus cni components."
    echo "--install-consul                Flag to install Consul Service Mesh Components."
    echo "                                DEFAULT: Don't install consul components."
    echo "--install-istio                 Flag to install Istio Service Mesh Components."
    echo "                                DEFAULT: Don't install istio components."
    echo "--install-metallb               Flag to install Metal LB Components."
    echo "                                DEFAULT: Don't install loadbalancer components."
    echo "--install-nginx-ingress         Flag to install Ingress Components - can't be used in combination with istio."
    echo "                                DEFAULT: Don't install ingress components."
    echo "--install-contour-ingress       Flag to install Ingress Components - can't be used in combination with istio."
    echo "                                DEFAULT: Don't install ingress components."
    echo "--install-haproxy-ingress       Flag to install Ingress Components - can't be used in combination with istio."
    echo "                                DEFAULT: Don't install ingress components."
    echo "--install-istio-gateway-api     Flag to install Istio Service Mesh Gateway API Components."
    echo "                                DEFAULT: Don't install istio components."
    echo "--install-contour-gateway-api   Flag to install Ingress Components - can't be used in combination with istio."
    echo "                                DEFAULT: Don't install ingress components."
    echo "--install-olm                   Flag to install Operator Lifecyle Manager"
    echo "                                DEFAULT: Don't install olm components."
    echo "                                Visit https://operatorhub.io to install available operators"
    echo "--delete                        Delete Kind cluster."
    echo ""
}

parse_args() {
    while [ "$1" != "" ]; do
        case $1 in
            --name )                          shift
                                              KIND_CLUSTER_NAME=$1
                                              ;;
            --num-workers )                   shift
                                              if ! [[ "$1" =~ ^[0-9]+$ ]]; then
                                                  echo "Invalid num-workers: $1"
                                                  usage
                                                  exit 1
                                              fi
                                              KIND_NUM_WORKER=$1
                                              ;;
            --config-file )                   shift
                                              if test ! -f "$1"; then
                                                  echo "$1 does not  exist"
                                                  usage
                                                  exit 1
                                              fi
                                              KIND_CONFIG=$1
                                              ;;
            --kubernetes-version )            shift
                                              KIND_K8S_VERSION=$1
                                              ;;
            --cluster-apiaddress )            shift
                                              KIND_CLUSTER_APIADDRESS=$1
                                              ;;
            --cluster-apiport )               shift
                                              KIND_CLUSTER_APIPORT=$1
                                              ;;
            --cluster-loglevel )              shift
                                              if ! [[ "$1" =~ ^[0-9]$ ]]; then
                                                  echo "Invalid cluster-loglevel: $1"
                                                  usage
                                                  exit 1
                                              fi
                                              KIND_CLUSTER_LOGLEVEL=$1
                                              ;;
            --cluster-podsubnet )             shift
                                              NET_CIDR_IPV4=$1
                                              ;;
            --cluster-svcsubnet )             shift
                                              SVC_CIDR_IPV4=$1
                                              ;;
            --disable-default-cni )           KIND_DISABLE_DEFAULT_CNI=true
                                              ;;
            --install-calico-cni )            KIND_INSTALL_CALICO_CNI=true
                                              ;;
            --install-cilium-cni )            KIND_INSTALL_CILIUM_CNI=true
                                              ;;
            --install-multus-cni )            KIND_INSTALL_MULTUS_CNI=true
                                              ;;
            --install-consul )                KIND_INSTALL_CONSUL=true
                                              ;;
            --install-istio )                 KIND_INSTALL_ISTIO=true
                                              ;;
            --install-metallb )               KIND_INSTALL_METALLB=true
                                              ;;
            --install-nginx-ingress )         KIND_INSTALL_NGINX_INGRESS=true
                                              ;;
            --install-contour-ingress )       KIND_INSTALL_CONTOUR_INGRESS=true
                                              ;;
            --install-haproxy-ingress )       KIND_INSTALL_HAPROXY_INGRESS=true
                                              ;;
            --install-istio-gateway-api )     KIND_INSTALL_ISTIO_GATEWAY_API=true
                                              ;;
            --install-contour-gateway-api )   KIND_INSTALL_CONTOUR_GATEWAY_API=true
                                              ;;
            --install-olm )                   KIND_INSTALL_OLM=true
                                              ;;
            --delete )                        delete
                                              exit
                                              ;;
            --help )                          usage
                                              exit
                                              ;;
            * )                               usage
                                              exit 1
        esac
        shift
    done
}

set_default_params() {
  KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
  KIND_CONFIG=${KIND_CONFIG:-./kind.yaml.j2}
  KIND_K8S_VERSION=${KIND_K8S_VERSION:-v1.21.1}
  KIND_NUM_WORKER=${KIND_NUM_WORKER:-0}
  KIND_CLUSTER_APIADDRESS=${KIND_CLUSTER_APIADDRESS:-0.0.0.0}
  KIND_CLUSTER_APIPORT=${KIND_CLUSTER_APIPORT:-6443}
  KIND_CLUSTER_LOGLEVEL=${KIND_CLUSTER_LOGLEVEL:-4}
  KIND_DISABLE_DEFAULT_CNI=${KIND_DISABLE_DEFAULT_CNI:-false}
  KIND_INSTALL_CALICO_CNI=${KIND_INSTALL_CALICO_CNI:-false}
  KIND_INSTALL_CILIUM_CNI=${KIND_INSTALL_CILIUM_CNI:-false}
  KIND_INSTALL_MULTUS_CNI=${KIND_INSTALL_MULTUS_CNI:-false}
  KIND_INSTALL_CONSUL=${KIND_INSTALL_CONSUL:-false}
  KIND_INSTALL_ISTIO=${KIND_INSTALL_ISTIO:-false}
  KIND_INSTALL_METALLB=${KIND_INSTALL_METALLB:-false}
  KIND_INSTALL_NGINX_INGRESS=${KIND_INSTALL_NGINX_INGRESS:-false}
  KIND_INSTALL_CONTOUR_INGRESS=${KIND_INSTALL_CONTOUR_INGRESS:-false}
  KIND_INSTALL_HAPROXY_INGRESS=${KIND_INSTALL_HAPROXY_INGRESS:-false}
  KIND_INSTALL_ISTIO_GATEWAY_API=${KIND_INSTALL_ISTIO_GATEWAY_API:-false}
  KIND_INSTALL_CONTOUR_GATEWAY_API=${KIND_INSTALL_CONTOUR_GATEWAY_API:-false}
  KIND_INSTALL_OLM=${KIND_INSTALL_OLM:-false}
  NET_CIDR_IPV4=${NET_CIDR_IPV4:-10.128.0.0/14}
  SVC_CIDR_IPV4=${SVC_CIDR_IPV4:-172.30.0.0/16}
}

print_params() {
     echo "Using these parameters to install KIND"
     echo ""
     echo "KIND_CLUSTER_NAME = $KIND_CLUSTER_NAME"
     echo "KIND_NUM_WORKER = $KIND_NUM_WORKER"
     echo "KIND_CONFIG_FILE = $KIND_CONFIG"
     echo "KIND_KUBERNETES_VERSION = $KIND_K8S_VERSION"
     echo "KIND_CLUSTER_APIADDRESS = $KIND_CLUSTER_APIADDRESS"
     echo "KIND_CLUSTER_APIPORT = $KIND_CLUSTER_APIPORT"
     echo "KIND_CLUSTER_LOGLEVEL = $KIND_CLUSTER_LOGLEVEL"
     echo "KIND_CLUSTER_PODSUBNET = $NET_CIDR_IPV4"
     echo "KIND_CLUSTER_SVCSUBNET = $SVC_CIDR_IPV4"
     echo "KIND_DISABLE_DEFAULT_CNI = $KIND_DISABLE_DEFAULT_CNI"
     echo "KIND_INSTALL_CALICO_CNI = $KIND_INSTALL_CALICO_CNI"
     echo "KIND_INSTALL_CILIUM_CNI = $KIND_INSTALL_CILIUM_CNI"
     echo "KIND_INSTALL_MULTUS_CNI = $KIND_INSTALL_MULTUS_CNI"
     echo "KIND_INSTALL_CONSUL = $KIND_INSTALL_CONSUL"
     echo "KIND_INSTALL_ISTIO = $KIND_INSTALL_ISTIO"
     echo "KIND_INSTALL_METALLB = $KIND_INSTALL_METALLB"
     echo "KIND_INSTALL_NGINX_INGRESS = $KIND_INSTALL_NGINX_INGRESS"
     echo "KIND_INSTALL_CONTOUR_INGRESS = $KIND_INSTALL_CONTOUR_INGRESS"
     echo "KIND_INSTALL_HAPROXY_INGRESS = $KIND_INSTALL_HAPROXY_INGRESS"
     echo "KIND_INSTALL_ISTIO_GATEWAY_API = $KIND_INSTALL_ISTIO_GATEWAY_API"
     echo "KIND_INSTALL_CONTOUR_GATEWAY_API = $KIND_INSTALL_CONTOUR_GATEWAY_API"
     echo "KIND_INSTALL_OLM = $KIND_INSTALL_OLM"
     echo ""
}

generate_kind_config() {
  cat <<EOF >>kind.yaml.j2
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
{%- if disable_default_cni is equalto "true" %}
  disableDefaultCNI: true
{%- endif %}
  apiServerAddress: {{ cluster_apiaddress }}
  apiServerPort: {{ cluster_apiport }}
{%- if net_cidr %}
  podSubnet: "{{ net_cidr }}"
{%- endif %}
{%- if svc_cidr %}
  serviceSubnet: "{{ svc_cidr }}"
{%- endif %}
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  metadata:
    name: config
  apiServer:
    extraArgs:
      "v": "{{ cluster_loglevel }}"
  controllerManager:
    extraArgs:
      "v": "{{ cluster_loglevel }}"
  scheduler:
    extraArgs:
      "v": "{{ cluster_loglevel }}"
  ---
  kind: InitConfiguration
  nodeRegistration:
    kubeletExtraArgs:
      "v": "{{ cluster_loglevel }}"
nodes:
 - role: control-plane
   kubeadmConfigPatches:
   - |
     kind: InitConfiguration
     nodeRegistration:
       kubeletExtraArgs:
         node-labels: "ingress-ready=true"
         authorization-mode: "AlwaysAllow"
   extraPortMappings:
{%- if install_nginx is equalto "true" %}
   - containerPort: 80
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 443
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- if install_haproxy is equalto "true" %}
   - containerPort: 80
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 443
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- if install_contour is equalto "true" %}
   - containerPort: 80
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 443
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- if install_contour_gateway_api is equalto "true" %}
   - containerPort: 30080
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30443
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- if install_consul is equalto "true" %}
   - containerPort: 30000
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30001
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30002
     hostPort: 15021
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- if install_istio is equalto "true" %}
   - containerPort: 30000
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30001
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30002
     hostPort: 15021
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- if install_istio_gateway_api is equalto "true" %}
   - containerPort: 30000
     hostPort: 80
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30001
     hostPort: 443
     listenAddress: "0.0.0.0"
     protocol: TCP
   - containerPort: 30002
     hostPort: 15021
     listenAddress: "0.0.0.0"
     protocol: TCP
{%- endif %}
{%- for _ in range(num_worker | int) %}
 - role: worker
{%- endfor %}
EOF
}

create_kind_cluster() {
  KIND_CONFIG_LCL=./kind.yaml

  num_worker=${KIND_NUM_WORKER} \
    cluster_loglevel=${KIND_CLUSTER_LOGLEVEL} \
    cluster_apiaddress=${KIND_CLUSTER_APIADDRESS} \
    cluster_apiport=${KIND_CLUSTER_APIPORT} \
    disable_default_cni=$KIND_DISABLE_DEFAULT_CNI \
    install_consul=$KIND_INSTALL_CONSUL \
    install_istio=$KIND_INSTALL_ISTIO \
    install_nginx=$KIND_INSTALL_NGINX_INGRESS \
    install_contour=$KIND_INSTALL_CONTOUR_INGRESS \
    install_haproxy=$KIND_INSTALL_HAPROXY_INGRESS \
    install_istio_gateway_api=$KIND_INSTALL_ISTIO_GATEWAY_API \
    install_contour_gateway_api=$KIND_INSTALL_CONTOUR_GATEWAY_API \
    net_cidr=${NET_CIDR_IPV4} \
    svc_cidr=${SVC_CIDR_IPV4} \
    j2 "${KIND_CONFIG}" -o "${KIND_CONFIG_LCL}"

  if kind get clusters | grep "${KIND_CLUSTER_NAME}"; then
    delete
  fi
  kind create cluster --name "${KIND_CLUSTER_NAME}" --image kindest/node:"${KIND_K8S_VERSION}" --config=${KIND_CONFIG_LCL}
  kind export kubeconfig --name "${KIND_CLUSTER_NAME}"
  rm ./kind.yaml
  rm ./kind.yaml.j2
}

delete() {
  kind delete cluster --name "${KIND_CLUSTER_NAME:-kind}"
}

kubectl_scaledown_coredns() {
  run_kubectl scale deployment --replicas 1 coredns --namespace kube-system
}

install_calico_cni() {
  # https://www.projectcalico.org
  run_kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  sleep 15
  if ! kubectl wait -n kube-system --for=condition=ready pods -l k8s-app=calico-node --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n kube-system || true
    exit 1
  fi
}

install_cilium_cni() {
  # https://docs.cilium.io/en/v1.9/gettingstarted/kind
  helm repo add cilium https://helm.cilium.io/
  helm install cilium cilium/cilium --version 1.9.6 \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set bpf.masquerade=false \
   --set image.pullPolicy=IfNotPresent \
   --set ipam.mode=kubernetes
  run_kubectl scale deployment --replicas 1 cilium-operator --namespace kube-system
}

install_multus_cni () {
  # https://github.com/k8snetworkplumbingwg/multus-cni
  run_kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
  sleep 15
  if ! kubectl wait -n kube-system --for=condition=ready pods -l app=multus --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n kube-system || true
    exit 1
  fi
  # https://github.com/containernetworking/plugins
  kubectl apply -f -<<EOF
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: cni-install-sh
  namespace: kube-system
data:
  install_cni.sh: |
    cd /tmp
    wget https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
    cd /host/opt/cni/bin
    tar xvfzp /tmp/cni-plugins-linux-amd64-v0.9.1.tgz
    sleep infinite
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: install-cni-plugins
  namespace: kube-system
  labels:
    name: cni-plugins
spec:
  selector:
    matchLabels:
      name: cni-plugins
  template:
    metadata:
      labels:
        name: cni-plugins
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/arch: amd64
      tolerations:
      - operator: Exists
        effect: NoSchedule
      containers:
      - name: install-cni-plugins
        image: alpine
        command: ["/bin/sh", "/scripts/install_cni.sh"]
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: true
        volumeMounts:
        - name: cni-bin
          mountPath: /host/opt/cni/bin
        - name: scripts
          mountPath: /scripts
      volumes:
        - name: cni-bin
          hostPath:
            path: /opt/cni/bin
        - name: scripts
          configMap:
            name: cni-install-sh
            items:
            - key: install_cni.sh
              path: install_cni.sh
EOF
  sleep 15
  if ! kubectl wait -n kube-system --for=condition=ready pods -l name=cni-plugins --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n kube-system || true
    exit 1
  fi
  kubectl apply -f -<<EOF
---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: ipvlan
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "ipvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.1.0/24",
        "rangeStart": "192.168.1.200",
        "rangeEnd": "192.168.1.219",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "192.168.1.1"
      }
    }'
EOF
}

generate_istio_profile() {
  cat <<EOF >>kind-istio.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    base:
      enabled: true
    cni:
      enabled: true
    egressGateways:
    - enabled: true
      k8s:
        env:
        - name: ISTIO_META_ROUTER_MODE
          value: standard
        hpaSpec:
          maxReplicas: 1
          metrics:
          - resource:
              name: cpu
              targetAverageUtilization: 80
            type: Resource
          minReplicas: 1
          scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: istio-egressgateway
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
          requests:
            cpu: 20m
            memory: 64Mi
        service:
          ports:
          - name: http2
            port: 80
            protocol: TCP
            targetPort: 8080
          - name: https
            port: 443
            protocol: TCP
            targetPort: 8443
          - name: tls
            port: 15443
            protocol: TCP
            targetPort: 15443
        strategy:
          rollingUpdate:
            maxSurge: 100%
            maxUnavailable: 25%
      name: istio-egressgateway
    ingressGateways:
    - enabled: true
      k8s:
        env:
        - name: ISTIO_META_ROUTER_MODE
          value: standard
        hpaSpec:
          maxReplicas: 1
          metrics:
          - resource:
              name: cpu
              targetAverageUtilization: 80
            type: Resource
          minReplicas: 1
          scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: istio-ingressgateway
        resources:
          limits:
            cpu: 2000m
            memory: 1024Mi
          requests:
            cpu: 20m
            memory: 64Mi
        nodeSelector:
          ingress-ready: "true"
        service:
          type: NodePort
          ports:
          - name: status-port
            port: 15021
            protocol: TCP
            targetPort: 15021
            nodePort: 30002
          - name: http2
            port: 80
            protocol: TCP
            targetPort: 8080
            nodePort: 30000
          - name: https
            port: 443
            protocol: TCP
            targetPort: 8443
            nodePort: 30001
          - name: tcp-istiod
            port: 15012
            protocol: TCP
            targetPort: 15012
            nodePort: 30003
          - name: tls
            port: 15443
            protocol: TCP
            targetPort: 15443
            nodePort: 30004
        strategy:
          rollingUpdate:
            maxSurge: 100%
            maxUnavailable: 25%
      name: istio-ingressgateway
    istiodRemote:
      enabled: false
    pilot:
      enabled: true
      k8s:
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 3
          timeoutSeconds: 5
        strategy:
          rollingUpdate:
            maxSurge: 100%
            maxUnavailable: 25%
  hub: docker.io/istio
  meshConfig:
    # outboundTrafficPolicy:
    #   mode: REGISTRY_ONLY
    enableTracing: true
    defaultConfig:
      tracing:
        sampling: 100
        zipkin:
          # address: jaeger-collector-headless.observability:9411
          address: zipkin.istio-system:9411
      proxyMetadata: {}
    enablePrometheusMerge: true
  profile: default
  tag: 1.10.0
  values:
    sidecarInjectorWebhook:
      injectedAnnotations:
        k8s.v1.cni.cncf.io/networks: istio-cni
    base:
      enableCRDTemplates: false
      validationURL: ""
    gateways:
      istio-egressgateway:
        autoscaleEnabled: false
        env: {}
        name: istio-egressgateway
        secretVolumes:
        - mountPath: /etc/istio/egressgateway-certs
          name: egressgateway-certs
          secretName: istio-egressgateway-certs
        - mountPath: /etc/istio/egressgateway-ca-certs
          name: egressgateway-ca-certs
          secretName: istio-egressgateway-ca-certs
        type: ClusterIP
        zvpn: {}
      istio-ingressgateway:
        autoscaleEnabled: false
        env: {}
        name: istio-ingressgateway
        secretVolumes:
        - mountPath: /etc/istio/ingressgateway-certs
          name: ingressgateway-certs
          secretName: istio-ingressgateway-certs
        - mountPath: /etc/istio/ingressgateway-ca-certs
          name: ingressgateway-ca-certs
          secretName: istio-ingressgateway-ca-certs
        type: LoadBalancer
        zvpn: {}
    global:
      configValidation: true
      defaultNodeSelector: {}
      defaultPodDisruptionBudget:
        enabled: true
      defaultResources:
        requests:
          cpu: 10m
      imagePullPolicy: ""
      imagePullSecrets: []
      istioNamespace: istio-system
      istiod:
        enableAnalysis: false
      jwtPolicy: third-party-jwt
      logAsJson: false
      logging:
        level: default:info
      mountMtlsCerts: false
      multiCluster:
        clusterName: ""
        enabled: false
      network: ""
      omitSidecarInjectorConfigMap: false
      oneNamespace: false
      operatorManageWebhooks: false
      pilotCertProvider: istiod
      priorityClassName: ""
      proxy:
        autoInject: enabled
        clusterDomain: cluster.local
        componentLogLevel: misc:error
        enableCoreDump: false
        excludeIPRanges: ""
        excludeInboundPorts: ""
        excludeOutboundPorts: ""
        image: proxyv2
        includeIPRanges: '*'
        logLevel: warning
        privileged: false
        readinessFailureThreshold: 30
        readinessInitialDelaySeconds: 1
        readinessPeriodSeconds: 2
        resources:
          limits:
            cpu: 2000m
            memory: 1024Mi
          requests:
            cpu: 20m
            memory: 64Mi
        statusPort: 15020
        tracer: zipkin
      proxy_init:
        image: proxyv2
        resources:
          limits:
            cpu: 2000m
            memory: 1024Mi
          requests:
            cpu: 10m
            memory: 10Mi
      sds:
        token:
          aud: istio-ca
      sts:
        servicePort: 0
      tracer:
        datadog: {}
        lightstep: {}
        stackdriver: {}
        zipkin: {}
      useMCP: false
    istiodRemote:
      injectionURL: ""
    pilot:
      autoscaleEnabled: false
      autoscaleMax: 5
      autoscaleMin: 1
      configMap: true
      cpu:
        targetAverageUtilization: 80
      enableProtocolSniffingForInbound: true
      enableProtocolSniffingForOutbound: true
      env: {}
      image: pilot
      keepaliveMaxServerConnectionAge: 30m
      nodeSelector: {}
      replicaCount: 1
      traceSampling: 1
    sidecarInjectorWebhook:
      enableNamespacesByDefault: false
      objectSelector:
        autoInject: true
        enabled: false
      rewriteAppHTTPProbe: true
    telemetry:
      enabled: true
      v2:
        enabled: true
        metadataExchange:
          wasmEnabled: false
        prometheus:
          enabled: true
          wasmEnabled: false
        stackdriver:
          configOverride: {}
          enabled: false
          logging: false
          monitoring: false
          topology: false
EOF
}

install_consul() {
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm install -f config.yaml consul hashicorp/consul --create-namespace -n consul --version "$CONSUL_VERSION"
}

install_istio() {
  # https://istio.io
  # Extract default install profile run ./istioctl profile dump > istio/profile.yaml
  istioctl install -y -f ./kind-istio.yaml
  rm ./kind-istio.yaml
}

install_metallb() {
  # https://github.com/metallb/metallb
  run_kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/namespace.yaml
  kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
  run_kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/metallb.yaml
  kubectl apply -f -<<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.18.255.200-172.18.255.250
EOF
  sleep 15
  if ! kubectl wait -n metallb-system --for=condition=ready pods --all --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n metallb-system || true
    exit 1
  fi
}

install_nginx_ingress() {
  # https://github.com/kubernetes/ingress-nginx
  VERSION=$(curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/stable.txt)
  run_kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/${VERSION}/deploy/static/provider/kind/deploy.yaml
}

install_contour_ingress() {
  # https://projectcontour.io
  run_kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
  run_kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
  run_kubectl scale deployment --replicas 1 contour --namespace projectcontour
  sleep 15
  if ! kubectl wait -n projectcontour --for=condition=ready pods -l app=contour --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n projectcontour || true
    exit 1
  fi
}

install_haproxy_ingress(){
  # https://haproxy-ingress.github.io/docs/getting-started/
  helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
  helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
  --create-namespace --namespace ingress-haproxy \
  --version 0.13.0 \
  -f -<<EOF
controller:
  hostNetwork: true
  service:
    httpPorts:
      - port: 80
        targetPort: http
    httpsPorts:
      - port: 443
        targetPort: https
    type: NodePort
EOF
}

install_istio_gateway_api() {
  # https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api
  kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0" | kubectl apply -f -
  istioctl install -f ./kind-istio.yaml --set values.pilot.env.PILOT_ENABLED_SERVICE_APIS=true -y
  rm ./kind-istio.yaml
}

install_contour_gateway_api() {
  # https://projectcontour.io/guides/gateway-api
  run_kubectl apply -f https://projectcontour.io/quickstart/operator.yaml
  sleep 15
  if ! kubectl wait -n contour-operator --for=condition=ready pods --all --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n contour-operator || true
    exit 1
  fi
}

install_olm() {
  # https://github.com/operator-framework/operator-lifecycle-manager/blob/master/doc/install/install.md
  run_kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml
  sleep 15
  run_kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml
  sleep 15
  if ! kubectl wait -n olm --for=condition=ready pods --all --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n olm || true
    exit 1
  fi
  run_kubectl scale deployment --replicas 1 packageserver --namespace olm
}

kubectl_wait_pods() {
  sleep 15
  if ! kubectl wait -n kube-system --for=condition=ready pods --all --timeout=300s ; then
    echo "some pods in the system are not running"
    run_kubectl get pods -A -o wide -n kube-system || true
    exit 1
  fi
}

parse_args "$@"
if [ $(groups "$(id -un)" | grep -q ' sudo ' && echo yes || echo no) == yes ]; then
  install_kind_cli
  install_kubectl_cli
  install_kustomize_cli
  install_helm_cli
  install_istioctl_cli
fi
install_j2_renderer
set_default_params
print_params
set -euxo pipefail
generate_kind_config
create_kind_cluster
kubectl_scaledown_coredns
if [ "$KIND_INSTALL_CALICO_CNI" == true ]; then
  install_calico_cni
fi
if [ "$KIND_INSTALL_CILIUM_CNI" == true ]; then
  install_cilium_cni
fi
if [ "$KIND_INSTALL_MULTUS_CNI" == true ]; then
  install_multus_cni
fi
if [ "$KIND_INSTALL_CONSUL" == true ]; then
  install_consul
fi
if [ "$KIND_INSTALL_ISTIO" == true ]; then
  generate_istio_profile
  install_istio
fi
if [ "$KIND_INSTALL_METALLB" == true ]; then
  install_metallb
fi
if [ "$KIND_INSTALL_NGINX_INGRESS" == true ]; then
  install_nginx_ingress
fi
if [ "$KIND_INSTALL_CONTOUR_INGRESS" == true ]; then
  install_contour_ingress
fi
if [ "$KIND_INSTALL_HAPROXY_INGRESS" == true ]; then
  install_haproxy_ingress
fi
if [ "$KIND_INSTALL_ISTIO_GATEWAY_API" == true ]; then
  generate_istio_profile
  install_istio_gateway_api
fi
if [ "$KIND_INSTALL_CONTOUR_GATEWAY_API" == true ]; then
  install_contour_gateway_api
fi
if [ "$KIND_INSTALL_OLM" == true ]; then
  install_olm
fi
kubectl_wait_pods
