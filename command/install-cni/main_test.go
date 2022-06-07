package installcni

import (
	"os"
	"path/filepath"
	"testing"
)

// TODO: Test scenario where a goes from .conf to .conflist
// TODO: Test multus plugin
func TestCreateCNIConfigFile(t *testing.T) {
	cases := []struct {
		name         string
		consulConfig *CNIConfig
		srcFile      string // source config file that we would expect to see in /opt/cni/net.d
		destFile     string // destination file that we write (sometimes the name changes from .conf -> .conflist)
		goldenFile   string // golden file that our output should look like
	}{
		{
			name:         "valid kindnet file",
			consulConfig: &CNIConfig{},
			srcFile:      "10-kindnet.conflist",
			destFile:     "10-kindnet.conflist",
			goldenFile:   "10-kindnet.conflist.golden",
		},
	}

	// set context so that the command will timeout

	// Create a default config
	cfg := &CNIConfig{
		Name:       defaultName,
		Type:       defaultType,
		CNIBinDir:  defaultCNIBinDir,
		CNINetDir:  defaultCNINetDir,
		Multus:     defaultMultus,
		Kubeconfig: defaultKubeconfig,
		LogLevel:   defaultLogLevel,
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {

			tempDir := t.TempDir()
			cfg.CNINetDir = tempDir
			// Copy test data to temporary directory to simulate the original config file on a host
			if err := copy(filepath.Join("testdata", c.srcFile), tempDir, c.srcFile); err != nil {
				t.Fatal(err)
			}

			err := appendCNIConfig(cfg, c.srcFile, c.destFile, nil)
			if err != nil {
				t.Fatal(err)
			}
		})
	}
}

func copy(srcFilepath, targetDir, targetFilename string) error {
	info, err := os.Stat(srcFilepath)
	if err != nil {
		return err
	}

	input, err := os.ReadFile(srcFilepath)
	if err != nil {
		return err
	}

	return os.WriteFile(filepath.Join(targetDir, targetFilename), input, info.Mode())
}
