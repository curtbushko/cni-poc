package installcni

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"github.com/containernetworking/cni/libcni"
	"github.com/hashicorp/consul-k8s/control-plane/subcommand/common"
	"github.com/hashicorp/consul-k8s/control-plane/subcommand/flags"
	"github.com/hashicorp/go-hclog"
	"github.com/mitchellh/cli"
	"github.com/mitchellh/mapstructure"
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
	Name string `json:"name" mapstructure:"name"`
	// Type of plugin (consul-cni)
	Type string `json:"type" mapstructure:"type"`
	// CNIBinDir is the location of the cni config files on the node. Can bet as a cli flag.
	CNIBinDir string `json:"cni_bin_dir" mapstructure:"cni_bin_dir"`
	// CNINetDir is the locaion of the cni plugin on the node. Can be set as a cli flag.
	CNINetDir string `json:"cni_net_dir" mapstructure:"cni_net_dir"`
	// Multus is if the plugin is a multus plugin. Can be set as a cli flag.
	Multus bool `json:"multus" mapstructure:"multus"`
	// Kubeconfig file name. Can be set as a cli flag.
	Kubeconfig string `json:"kubeconfig" mapstructure:"kubeconfig"`
	// LogLevl is the logging level. Can be set as a cli flag.
	LogLevel string `json:"log_level" mapstructure:"log_level"`
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
	c.flagSet.StringVar(&c.flagCNIBinSourceDir, "bin-source-dir", defaultCNIBinSourceDir, "Host location to copy the binary from")
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
	cfg, err := c.NewCNIConfig()
	if err != nil {
		return 1
	}

	srcFile, err := getDefaultCNINetwork(cfg.CNINetDir, c.logger)
	if err != nil {
		return 1
	}

	destFile, err := getDestFile(srcFile, c.logger)

	err = appendCNIConfig(cfg, srcFile, destFile, c.logger)
	if err != nil {
		return 1
	}

	// TODO: get config file
	// TODO: read config file into byte[]
	// TODO: convert config struct into map using mitchellh/mapstructure. see server-acl-init command.go

	return 0

}

func (c *Command) NewCNIConfig() (*CNIConfig, error) {
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

func (c *Command) NewInstallConfig() (*installConfig, error) {
	return &installConfig{
		CNIBinSourceDir: c.flagCNIBinSourceDir,
	}, nil
}

func appendCNIConfig(cfg *CNIConfig, srcFile, destFile string, logger hclog.Logger) error {

	// Needed to convert the config struct for inserting
	// Check if file exists
	srcFilePath := filepath.Join(cfg.CNINetDir, srcFile)
	_, err := os.Stat(srcFilePath)
	if _, err := os.Stat(srcFilePath); os.IsNotExist(err) {
		return fmt.Errorf("Source cni config file %s does not exist", srcFilePath)
	}

	// This section overwrites an existing plugins list entry for istio-cni
	existingCNIConfig, err := os.ReadFile(srcFilePath)
	if err != nil {
		return err
	}

	// convert the consul-cni struct into a map
	var cfgMap map[string]interface{}
	err = mapstructure.Decode(cfg, &cfgMap)
	if err != nil {
		return fmt.Errorf("error loading Consul CNI config: %v", err)
	}

	// Convert the json config file into a map. The map that is created has 2 parts:
	// [0] the cni header ()
	var existingMap map[string]interface{}
	err = json.Unmarshal(existingCNIConfig, &existingMap)
	if err != nil {
		return fmt.Errorf("error unmarshalling existing CNI config: %v", err)
	}

	// Get the 'plugins' map embedded inside of the exisingMap
	plugins, ok := existingMap["plugins"].([]interface{})
	if !ok {
		return fmt.Errorf("error reading plugin list from CNI config")
	}

	// Append the consul-cni map to the already existing plugins
	existingMap["plugins"] = append(plugins, cfgMap)

	// Marshal into a new json file
	existingJson, err := json.MarshalIndent(existingMap, "", "  ")
	existingJson = append(existingJson, "\n"...)

	// Write the file out

	err = os.WriteFile(destFile, existingJson, os.FileMode(0o644))
	if err != nil {
		return fmt.Errorf("error writing config file %s: %v", destFile, err)
	}

	return nil
}

// Get the correct config file
// Adapted from kubelet: https://github.com/kubernetes/kubernetes/blob/954996e231074dc7429f7be1256a579bedd8344c/pkg/kubelet/dockershim/network/cni/cni.go#L134
func getDefaultCNINetwork(confDir string, logger hclog.Logger) (string, error) {
	files, err := libcni.ConfFiles(confDir, []string{".conf", ".conflist", ".json"})
	switch {
	case err != nil:
		return "", err
	case len(files) == 0:
		return "", fmt.Errorf("No networks found in %s", confDir)
	}

	sort.Strings(files)
	for _, confFile := range files {
		var confList *libcni.NetworkConfigList
		if strings.HasSuffix(confFile, ".conflist") {
			confList, err = libcni.ConfListFromFile(confFile)
			if err != nil {
				logger.Warn("Error loading CNI config list file %s: %v", confFile, err)
				continue
			}
		} else {
			conf, err := libcni.ConfFromFile(confFile)
			if err != nil {
				logger.Warn("Error loading CNI config file %s: %v", confFile, err)
				continue
			}
			// Ensure the config has a "type" so we know what plugin to run.
			// Also catches the case where somebody put a conflist into a conf file.
			if conf.Network.Type == "" {
				logger.Warn("Error loading CNI config file %s: no 'type'; perhaps this is a .conflist?", confFile)
				continue
			}

			confList, err = libcni.ConfListFromConf(conf)
			if err != nil {
				logger.Warn("Error converting CNI config file %s to list: %v", confFile, err)
				continue
			}
		}
		if len(confList.Plugins) == 0 {
			logger.Warn("CNI config list %s has no networks, skipping", confFile)
			continue
		}

		logger.Info("Using CNI configuration file %s", confFile)
		return filepath.Base(confFile), nil
	}
	return "", fmt.Errorf("No valid networks found in %s", confDir)
}

func getDestFile(srcFile string, logger hclog.Logger) (string, error) {
	return srcFile, nil
}

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
