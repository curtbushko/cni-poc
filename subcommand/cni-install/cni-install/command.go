package cniinstall

// TODO: Read environment variables for options
// TODO: Follow linkerd, they read the configmap and assign the contents to env variables thus avoiding chicken and egg. Everything needed is in the configmap. Why does istio mix like this?

import (
	"github.com/hashicorp/consul-k8s/control-plane/subcommand/common"
	"github.com/hashicorp/consul-k8s/control-plane/subcommand/flags"
	"github.com/mitchellh/cli"
)

// Command struct
type Command struct {
	UI cli.Ui

	flags *flag.FlagSet

	flagCniBinDir string
	flagCniNetDir string
	flagChained   bool
}
