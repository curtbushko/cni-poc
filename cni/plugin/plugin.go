package plugin


package plugin

const (
  defaultName = "consul-cni"
  defaultType = "consul-cni"
  defaultLogLevel = "info"
  defaultChained = true
  defaultCniBinDir = "/etc/cni/net.d"
  defaultCniNetDir = "/opt/cni/bin"
  defaultKubeConfig = "ZZZ-consul-cni-kubeconfig"
)

type Config struct {
  // Name of the plugin

  // CniBinDir is the default location for the plugin binary
  
  // CniNetDir is the default location for CNI plugin configuration files
}                       
