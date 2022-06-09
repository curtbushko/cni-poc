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

// TODO: Add description that explains the difference between CNIConfig and installConfig

// CNIConfig are the values that are generated for the CNI plugin to use.
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

// installConfig are the values by the installer when running inside a container
type installConfig struct {
	// TODO: Add descriptions
	MountedCNIBinDir string
	MountedCNINetDir string
	CNIBinSourceDir  string
}

// Command flags and structure
type Command struct {
	UI cli.Ui

	flagCNIBinDir       string
	flagCNINetDir       string
	flagMultus          bool
	flagKubeconfig      string
	flagCNIBinSourceDir string
	flagLogLevel        string
	flagLogJSON         bool

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
	c.flagSet.StringVar(&c.flagLogLevel, "log-level", "debug", "Log verbosity level. Supported values (in order of detail) are \"trace\", "+
		"\"debug\", \"info\", \"warn\", and \"error\".")
	c.flagSet.BoolVar(&c.flagLogJSON, "log-json", false, "Enable or disable JSON output format for logging.")

	c.help = flags.Usage(help, c.flagSet)
}

// Run runs the command
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

	// Create the CNI Config from command flags
	cfg, err := c.newCNIConfig()
	if err != nil {
		c.logger.Error("Unable create new CNI config from command flags", "error", err)
		return 1
	}

	// Create the install Config for working with files
	install, err := c.newInstallConfig()
	if err != nil {
		c.logger.Error("Unable create new install config", "error", err)
		return 1
	}

	// Get the config file that is on the host
	srcFileName, err := getDefaultCNINetwork(install.MountedCNINetDir, c.logger)
	if err != nil {
		c.logger.Error("Unable get default config file", "error", err)
		return 1
	}

	// Get the dest file we will write to (the name can change)
	destFileName, err := getDestFile(srcFileName, c.logger)
	if err != nil {
		c.logger.Error("Unable get destination config file", "error", err)
		return 1
	}

	// Get the correct mounted file paths from inside the container
	srcFile := filepath.Join(install.MountedCNINetDir, srcFileName)
	destFile := filepath.Join(install.MountedCNINetDir, destFileName)
	// Append the consul configuration to the config that is there

	// TODO: Handle pod restarts and continuous appending of config
	// TODO: consul-cni binary needs chmod +x
	// TODO: Handle binary already exists, replace?
	// TODO: Add debug/info logging to functions
	err = appendCNIConfig(cfg, srcFile, destFile, c.logger)
	if err != nil {
		c.logger.Error("Unable add the consul-cni config to the config file", "error", err)
		return 1
	}

	// Generate the kubeconfig file
	err = createKubeConfig(install.MountedCNINetDir, cfg.Kubeconfig, c.logger)
	if err != nil {
		c.logger.Error("Unable to create kubeconfig file", "error", err)
		return 1
	}

	err = copyCNIBinary(install.CNIBinSourceDir, install.MountedCNIBinDir, c.logger)
	if err != nil {
		c.logger.Error("Unable to copy cni binary", "error", err)
		return 1
	}
	return 0

}

func (c *Command) newCNIConfig() (*CNIConfig, error) {
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

func (c *Command) newInstallConfig() (*installConfig, error) {
	return &installConfig{
		MountedCNIBinDir: "/host/" + c.flagCNIBinDir,
		MountedCNINetDir: "/host/" + c.flagCNINetDir,
		CNIBinSourceDir:  c.flagCNIBinSourceDir,
	}, nil
}

func appendCNIConfig(cfg *CNIConfig, srcFile, destFile string, logger hclog.Logger) error {

	// Needed to convert the config struct for inserting
	// Check if file exists
	if _, err := os.Stat(srcFile); os.IsNotExist(err) {
		return fmt.Errorf("source cni config file %s does not exist: %v", srcFile, err)
	}

	// This section overwrites an existing plugins list entry for istio-cni
	existingCNIConfig, err := os.ReadFile(srcFile)
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
	existingJSON, err := json.MarshalIndent(existingMap, "", "  ")
	if err != nil {
		return fmt.Errorf("error marshalling existing CNI config: %v", err)
	}
	existingJSON = append(existingJSON, "\n"...)

	// Write the file out
	err = os.WriteFile(destFile, existingJSON, os.FileMode(0o644))
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
		return "", fmt.Errorf("no networks found in %s", confDir)
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

		cFile := filepath.Base(confFile)
		logger.Info("Using CNI configuration file %s", cFile)
		return cFile, nil
	}
	return "", fmt.Errorf("no valid networks found in %s", confDir)
}

func getDestFile(srcFile string, logger hclog.Logger) (string, error) {
	logger.Info("CNI configuration destrination file %s", srcFile)
	return srcFile, nil
}

func copyCNIBinary(srcDir, destDir string, logger hclog.Logger) error {
	var filename = "consul-cni"

	// If the src file does not exist then either the incorrect command line argument was used or
	// the docker container we built is broken somehow.
	srcFile := filepath.Join(srcDir, filename)
	if _, err := os.Stat(srcFile); os.IsNotExist(err) {
		return fmt.Errorf("source cni binary %s does not exist: %v", srcFile, err)
	}

	// If the destDir does not exist then the incorrect command line argument was used or
	// the CNI settings for the kublet are not correct
	if _, err := os.Stat(destDir); os.IsNotExist(err) {
		return fmt.Errorf("destination directory %s does not exist: %v", destDir, err)
	}

	srcBytes, err := os.ReadFile(srcFile)
	if err != nil {
		return fmt.Errorf("could not read %s file: %v", srcFile, err)
	}

	err = os.WriteFile(filepath.Join(destDir, filename), srcBytes, os.FileMode(0o644))
	if err != nil {
		return fmt.Errorf("error copying consul-cni binary to %s: %v", destDir, err)
	}

	return nil
}

// Synopsis returns the summary of the cni install command
func (c *Command) Synopsis() string { return synopsis }

// Help returns the help output of the command
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
