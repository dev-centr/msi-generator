<a id="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]

<div align="center">
  <h1>MSI/MSIX Generator</h1>
  <p>A cross-platform MSI/MSIX generator in D-lang.</p>
  <p>
    <a href="https://dev-centr.github.io/msi-generator/">Explore the docs</a>
    ·
    <a href="https://github.com/dev-centr/msi-generator/issues">Report Bug</a>
    ·
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

## Usage

```bash
./msi-generator --name="MyApp" --id="com.example.myapp" --version="1.0.0.0" --exe="bin/myapp.exe" --output="myapp.msix"
```

### Antora Documentation

Documentation is located in the `docs` folder. To build the documentation:

```bash
npx antora docs/antora-playbook.yml
```

### Development Notes

#### Dependency: asdf

This project currently requires a patched version of `asdf` for `std.uuid` serialization support.
A PR has been submitted upstream: https://github.com/libmir/asdf/pull/30

Once merged and released (version > 0.7.17):

1. Update `dub.json` dependency for `asdf`.
2. Remove local override: `dub remove-local z:\code\libmir\asdf`.

## Contact

DevCentr.org — support@devcentr.org

Project Link: https://github.com/dev-centr/msi-generator

Site: https://devcentr.org

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/dev-centr/msi-generator.svg?style=for-the-badge
[contributors-url]: https://github.com/dev-centr/msi-generator/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/dev-centr/msi-generator.svg?style=for-the-badge
[forks-url]: https://github.com/dev-centr/msi-generator/network/members
[stars-shield]: https://img.shields.io/github/stars/dev-centr/msi-generator.svg?style=for-the-badge
[stars-url]: https://github.com/dev-centr/msi-generator/stargazers
[issues-shield]: https://img.shields.io/github/issues/dev-centr/msi-generator.svg?style=for-the-badge
[issues-url]: https://github.com/dev-centr/msi-generator/issues
