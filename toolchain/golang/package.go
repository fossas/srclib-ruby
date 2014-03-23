package golang

import (
	"path/filepath"

	"sourcegraph.com/sourcegraph/srcgraph/unit"
)

func init() {
	unit.Register("GoPackage", Package{})
}

type Package struct {
	Dir        string `toml:"dir"`
	ImportPath string `toml:"import_path"`
}

func (p Package) ID() string      { return "go:" + p.ImportPath }
func (p Package) Name() string    { return filepath.Base(p.Dir) }
func (p Package) RootDir() string { return p.Dir }
func (p Package) Paths() []string { return []string{p.Dir} }