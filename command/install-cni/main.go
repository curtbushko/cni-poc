package installcni

import (
	"flag"
	"sync"

	"github.com/hashicorp/consul-k8s/control-plane/subcommand/common"
	"github.com/hashicorp/consul-k8s/control-plane/subcommand/flags"
	"github.com/hashicorp/go-hclog"
	"github.com/mitchellh/cli"
)

const (
	defaultName                   = "consul-cni"
	defaultType                   = "consul-cni"
	defaultCNIBinDir              = "/opt/cni/bin"
	defaultCNINetDir              = "/etc/cni/net.d"
	defaultMultus                 = false
	defaultKubeconfig             = "ZZZZ-consul-cni-kubeconfig"
	defaultLogLevel               = "info"
	defaultCNINetworkTemplateFile = "consul-cni-config"
	defaultCNIBinSourceDir        = "/bin"
)

// CNIConfig are the values that are passed to the CNI plugin. Some of these values are also used by
// the installer
type CNIConfig struct {
	// Name of the plugin
	Name string `json:"name"`
	// Type of plugin (consul-cni)
	Type string `json:"type"`
	// CNIBinDir is the location of the cni config files on the node. Can bet as a cli flag.
	CNIBinDir string `json:"cni_bin_dir"`
	// CNINetDir is the locaion of the cni plugin on the node. Can be set as a cli flag.
	CNINetDir string `json:"cni_net_dir"`
	// Multus is if the plugin is a multus plugin. Can be set as a cli flag.
	Multus bool `json:"multus"`
	// Kubeconfig file name. Can be set as a cli flag.
	Kubeconfig string `json:"kubeconfig"`
	// LogLevl is the logging level. Can be set as a cli flag.
	LogLevel string `json:"log_level"`
}

// installConfig contains values that are specific to the installer. They are read at the command line
type installConfig struct {
	// Location of where to copy the cni plugin from
	CNIBinSourceDir string

	// TODO: We will need kubernetes specific config and a way to generate a kubeconfig file
}

type Command struct {
	UI cli.Ui

	flagCNIBinDir       string
	flagCNINetDir       string
	flagMultus          bool
	flagKubeconfig      string
	flagCNIBinSourceDir string
	flagLogLevel        string
	flagLogJSON         bool
	blah                bool

	flagSet *flag.FlagSet

	once   sync.Once
	help   string
	logger hclog.Logger
}

func (c *Command) init() {

	c.flagSet = flag.NewFlagSet("", flag.ContinueOnError)
	c.flagSet.StringVar(&c.flagCNIBinDir, "cni-bin-dir", defaultCNIBinDir, "Location of CNI plugin binaries.")
	c.flagSet.StringVar(&c.flagCNINetDir, "cni-net-dir", defaultCNINetDir, "Location to write the CNI plugin configuration.")
	c.flagSet.StringVar(&c.flagCNIBinSourceDir, "bin-source-dir", defaultCNIBinSourceDir, "Location of the consul-cni binary to install")
	c.flagSet.StringVar(&c.flagKubeconfig, "kubeconfig", defaultKubeconfig, "Name of the kubernetes config file")
	c.flagSet.BoolVar(&c.flagMultus, "multus", false, "If the plugin is a multus plugin (default = false)")
	c.flagSet.StringVar(&c.flagLogLevel, "log-level", "info", "Log verbosity level. Supported values (in order of detail) are \"trace\", "+
		"\"debug\", \"info\", \"warn\", and \"error\".")
	c.flagSet.BoolVar(&c.flagLogJSON, "log-json", false, "Enable or disable JSON output format for logging.")

	c.help = flags.Usage(help, c.flagSet)
}

func (c *Command) Run(args []string) int {
	var err error
	c.once.Do(c.init)

	if err := c.flagSet.Parse(args); err != nil {
		return 1
	}

	// TODO: Validate flags, especially log level

	// Set up logging.
	if c.logger == nil {
		var err error
		c.logger, err = common.Logger(c.flagLogLevel, c.flagLogJSON)
		if err != nil {
			c.UI.Error(err.Error())
			return 1
		}
	}
	cfg, err := createInstallConfig(c)
	if err != nil {
		return 1
	}
	// blah
	if cfg == nil {

	}
	return 0

}

func createCNIConfig(c *Command) (*CNIConfig, error) {
	return &CNIConfig{
		Name:       defaultName,
		Type:       defaultType,
		CNIBinDir:  c.flagCNIBinDir,
		CNINetDir:  c.flagCNINetDir,
		Multus:     c.flagMultus,
		Kubeconfig: c.flagKubeconfig,
		LogLevel:   c.flagLogLevel,
	}, nil
}

func createInstallConfig(c *Command) (*installConfig, error) {
	return &installConfig{
		CNIBinSourceDir: c.flagCNIBinSourceDir,
	}, nil
}

func (i *installConfig) generateConfigTemplate() {}

func (c *Command) Synopsis() string { return synopsis }
func (c *Command) Help() string {
	c.once.Do(c.init)
	return c.help
}

const synopsis = "Consul CNI plugin installer"
const help = `
Usage: consul-k8s-control-plane cni-install [options]

  Install Consul CNI plugin
  Not intended for stand-alone use.
`

const configTpl = `

`
