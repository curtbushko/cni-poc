package cniinstall

// TODO: Read environment variables for options
// TODO: In the helm chart, follow linkerd, they read the configmap and assign the contents to env variables thus avoiding chicken and egg. Everything needed is in the configmap. Why does istio mix like this?

import (
	"flag"
	"sync"

	"github.com/hashicorp/consul-k8s/control-plane/subcommand/flags"
	"github.com/hashicorp/go-hclog"
	"github.com/mitchellh/cli"
)

type InstallConfig struct {
	// Name of the plugin (CNI Spec)
	Name       string `json:"name"`        // Name of the plugin (CNI Spec)
	Type       string `json:"type"`        // Type of the plugin (CNI Spec, must match cni-consul binary name)
	LogLevel   string `json:"log_level"`   // (CNI Spec, must match cni-consul binary name)
	CNIBinDir  string `json:"cni_bin_dir"` // Log level for installer and plugin. Default info. (trace|debug|info|warn|error)
	CNINetDir  string `json:"cni_net_dir"` // CniNetDir is the default location for CNI plugin configuration files
	Chained    bool   `json:"chained"`     // Chained if the plugin is chained or multus
	KubeConfig string `json:"kube_config"` // KubeConfig is the location of the kube config file (ZZZ-consul-cni-kubeconfig)
}

// Command struct
type Command struct {
	UI cli.Ui

	flagCNIBinDir string // Location of cni binary
	flagCNINetDir string // Location of cni configuration file (used by cni-install command and cni plugin)
	flagChained   bool   // If the plugin is a chained or multus plugin. Affects how the config is written
	flagLogLevel  string // Log level for installer and plugin. Default info. (trace|debug|info|warn|error)

	flagSet *flag.FlagSet

	once   sync.Once
	help   string
	logger hclog.Logger
}

func (c *Command) init() {
	c.flagSet = flag.NewFlagSet("", flag.ContinueOnError)

	c.flagSet = flag.NewFlagSet("", flag.ContinueOnError)
	c.flagSet.StringVar(&c.flagCNIBinDir, "cni-bin-dir", "", "Location of the CNI binary")
	c.flagSet.StringVar(&c.flagCNINetDir, "cni-net-dir", "", "Location of the CNI configuration files")
	c.flagSet.BoolVar(&c.flagChained, "chained", true, "If the plugin is a chained or multus plugin")
	c.flagSet.StringVar(&c.flagLogLevel, "log-level", "info",
		"Log verbosity level. Supported values (in order of detail) are \"trace\", "+
			"\"debug\", \"info\", \"warn\", and \"error\".")
	c.help = flags.Usage(help, c.flagSet)
}

func (c *Command) Run(args []string) int {
	c.once.Do(c.init)
	return 0
}

func (c *Command) Synopsis() string { return synopsis }
func (c *Command) Help() string {
	c.once.Do(c.init)
	return c.help
}

const synopsis = "CNI install command."
const help = `
Usage: consul-k8s-control-plane cni-install [options]

  Install consul-CNI plugin components.
  Not intended for stand-alone use.
`
