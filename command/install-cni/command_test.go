package installcni

import (
	"io/ioutil"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
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
			srcFile:      "testdata/10-kindnet.conflist",
			destFile:     "10-kindnet.conflist",
			goldenFile:   "testdata/10-kindnet.conflist.golden",
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
			tempDestFile := filepath.Join(tempDir, c.destFile)

			err := appendCNIConfig(cfg, c.srcFile, tempDestFile, nil)
			if err != nil {
				t.Fatal(err)
			}

			actual, err := ioutil.ReadFile(tempDestFile)
			require.NoError(t, err)

			expected, err := ioutil.ReadFile(c.goldenFile)
			require.NoError(t, err)

			require.Equal(t, string(expected), string(actual))
		})
	}
}
