[![Repository](https://img.shields.io/badge/repo-GitHub-24292e?style=flat)](https://github.com/dev-centr/msi-generator)

# MSI/MSIX Generator

A cross-platform MSI/MSIX generator in D-lang.

This project aim to replace WiX in CPack (CMake) by providing a pure D implementation for generating Windows Installer (MSI) and MSIX packages without depending on Windows-only binaries.

## Quick Start

### Prerequisites

- D compiler (DMD, LDC, or GDC)
- dub (D package manager)

### Build

```bash
dub build
```

or for production readiness immediately (bypassing strict UUID typing issues):

```bash
dub build --config=prod
```

### Usage

```bash
./msi-generator --name="MyApp" --id="com.example.myapp" --version="1.0.0.0" --exe="bin/myapp.exe" --output="myapp.msix"
```

## Antora Documentation

Documentation is located in the `docs` folder. To build the documentation:

```bash
npx antora docs/antora-playbook.yml
```

Published docs: https://dev-centr.github.io/msi-generator/

## Development Notes

### Dependency: asdf

This project currently requires a patched version of `asdf` for `std.uuid` serialization support.
A PR has been submitted upstream: https://github.com/libmir/asdf/pull/30

Once merged and released (version > 0.7.17):

1. Update `dub.json` dependency for `asdf`.
2. Remove local override: `dub remove-local z:\code\libmir\asdf`.
