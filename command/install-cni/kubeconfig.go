package installcni

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"os"
	"text/template"

	"github.com/hashicorp/consul-k8s/control-plane/subcommand"
	"github.com/hashicorp/go-hclog"
	"k8s.io/client-go/rest"
)

type KubeConfigFields struct {
	KubernetesServiceProtocol string
	KubernetesServiceHost     string
	KubernetesServicePort     string
	TLSConfig                 string
	ServiceAccountToken       string
}

func createKubeConfig(mountedPath, kubeconfigFile string, logger hclog.Logger) error {

	var kubecfg *rest.Config
	// Use the in-cluster kubeconfig to connect to the kubeapi
	kubecfg, err := subcommand.K8SConfig("")
	if err != nil {
		return err
	}

	kubeFields, err := getKubernetesFields(kubecfg.CAData)
	if err != nil {
		return err
	}

	destFile := mountedPath + kubeconfigFile
	err = writeKubeConfig(kubeFields, destFile)
	if err != nil {
		return err
	}

	return nil
}

func getKubernetesFields(caData []byte) (*KubeConfigFields, error) {

	var protocol = "https"
	if val, ok := os.LookupEnv("KUBERNETES_SERVICE_PROTOCOL"); ok {
		protocol = val
	}

	var serviceHost string
	if val, ok := os.LookupEnv("KUBERNETES_SERVICE_HOST"); ok {
		serviceHost = val
	}

	var servicePort string
	if val, ok := os.LookupEnv("KUBERNETES_SERVICE_PORT"); ok {
		servicePort = val
	}

	ca := "certificate-authority-data: " + base64.StdEncoding.EncodeToString(caData)

	serviceToken, err := getServiceAccountToken()
	if err != nil {
		return nil, err
	}

	return &KubeConfigFields{
		KubernetesServiceProtocol: protocol,
		KubernetesServiceHost:     serviceHost,
		KubernetesServicePort:     servicePort,
		TLSConfig:                 ca,
		ServiceAccountToken:       serviceToken,
	}, nil
}

func getServiceAccountToken() (string, error) {
	token, err := ioutil.ReadFile(serviceAccountToken)
	if err != nil {
		return "", fmt.Errorf("could not read service account token: %v", err)
	}
	return string(token), nil

}

func writeKubeConfig(fields *KubeConfigFields, destFile string) error {

	tmpl, err := template.New("kubeconfig").Parse(kubeconfigTmpl)
	if err != nil {
		return fmt.Errorf("could not parse kube config template: %v", err)
	}

	var templateBuffer bytes.Buffer
	if err := tmpl.Execute(&templateBuffer, fields); err != nil {
		return fmt.Errorf("could not execute kube config template: %v", err)
	}

	err = os.WriteFile(destFile, templateBuffer.Bytes(), os.FileMode(0o644))
	if err != nil {
		return fmt.Errorf("error writing kube config file %s: %v", destFile, err)
	}

	return nil
}

const (
	serviceAccountToken = "/var/run/secrets/kubernetes.io/serviceaccount/token"
	kubeconfigTmpl      = `# Kubeconfig file for consul CNI plugin.
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: {{.KubernetesServiceProtocol}}://[{{.KubernetesServiceHost}}]:{{.KubernetesServicePort}}
    {{.TLSConfig}}
users:
- name: consul-cni
  user:
    token: "{{.ServiceAccountToken}}"
contexts:
- name: consul-cni-context
  context:
    cluster: local
    user: consul-cni
current-context: consul-cni-context
`
)