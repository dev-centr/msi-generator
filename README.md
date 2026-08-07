<a id="readme-top"></a>
<div align="center">
  <a href="https://github.com/dev-centr/msi-generator/graphs/contributors"><img src="https://img.shields.io/github/contributors/dev-centr/msi-generator.svg?style=for-the-badge" alt="Contributors"></a>
  <a href="https://github.com/dev-centr/msi-generator/network/members"><img src="https://img.shields.io/github/forks/dev-centr/msi-generator.svg?style=for-the-badge" alt="Forks"></a>
  <a href="https://github.com/dev-centr/msi-generator/stargazers"><img src="https://img.shields.io/github/stars/dev-centr/msi-generator.svg?style=for-the-badge" alt="Stargazers"></a>
  <a href="https://github.com/dev-centr/msi-generator/issues"><img src="https://img.shields.io/github/issues/dev-centr/msi-generator.svg?style=for-the-badge" alt="Issues"></a>

  <h3 align="center">MSI/MSIX Generator</h3>
  <p align="center">
    A cross-platform MSI/MSIX generator in D-lang.
    <br />
    <a href="https://docs.devcentr.org/msi-generator/"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/dev-centr/msi-generator/issues">Report Bug</a>
    &middot;
    <a href="https://github.com/dev-centr/msi-generator/issues">Request Feature</a>
  </p>
</div>

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

## About The Project

This project aims to replace WiX in CPack (CMake) with a pure D implementation for generating Windows Installer (MSI) and MSIX packages without Windows-only binaries. The current minimal MSI writer produces a real OLE Compound File database with core installer tables and an embedded uncompressed CAB; the MSIX writer produces a ZIP payload with manifest assets. Signing and advanced MSI authoring remain caller responsibilities.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Installation

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

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

```bash
./msi-generator --name="MyApp" --id="com.example.myapp" --version="1.0.0.0" --exe="bin/myapp.exe" --output="myapp.msix"
```

### Antora Documentation

Docs live on the Dev-Centr hub: https://docs.devcentr.org/msi-generator/
Component source is in `docs/` (wired via `dev-centr/docs`). Local build validates only — do not publish a secondary Antora site.

```bash
pnpm install
pnpm run build   # or: antora antora-playbook.yml
```

### Development Notes

#### Dependency: asdf

This project currently requires a patched version of `asdf` for `std.uuid` serialization support.
A PR has been submitted upstream: https://github.com/libmir/asdf/pull/30

Once merged and released (version > 0.7.17):

1. Update `dub.json` dependency for `asdf`.
2. Remove local override: `dub remove-local z:\code\libmir\asdf`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contact

DevCentr.org — support@devcentr.org

Project Link: [https://github.com/dev-centr/msi-generator](https://github.com/dev-centr/msi-generator)

Site: [https://devcentr.org](https://devcentr.org)

<p align="right">(<a href="#readme-top">back to top</a>)</p>
