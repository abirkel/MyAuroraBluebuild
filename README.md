# MyAuroraBluebuild

> Aurora-based Fedora Atomic image with maccel mouse acceleration and custom packages

A Blue Build-based custom image that provides [Aurora's](https://getaurora.dev/) excellent desktop experience with integrated maccel mouse acceleration and personalized package customization.

## Features

- **Aurora Base**: Built on Universal Blue's Aurora-nvidia for optimal gaming performance
- **Maccel Integration**: Built-in mouse acceleration driver with CLI and TUI interfaces
- **Package Customization**: Remove unwanted packages, add preferred alternatives
- **Blue Build Framework**: Standard tooling and community-supported approach
- **Cryptographic Signing**: Signed images for supply chain security

## Installation

Rebase your existing Fedora Atomic system:

```bash
# Rebase to signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/USERNAME/myaurorabluebuild:latest
systemctl reboot
```

## Maccel Usage

After installation, maccel is ready to use:

```bash
# Verify that the maccel module is loaded
lsmod | grep maccel

# Add your user to maccel group (one time setup)
sudo usermod -aG maccel $USER
# Log out and back in for group changes to take effect

# Launch interactive configuration
maccel tui

# Or use command line
maccel set --sensitivity 1.5
maccel set --curve "0.0 0.0 0.5 0.3 1.0 1.0"
maccel status
```

**Tips**:
- Start with the TUI (`maccel tui`) for an interactive experience
- Sensitivity values typically range from 0.5 (slower) to 2.0 (faster)
- Configuration persists across reboots

## Customization

This image is built using Blue Build's recipe.yml configuration. See `recipes/recipe.yml` for current package selections and customization options.

## Architecture

MyAuroraBluebuild coordinates with [maccel-rpm-builder](../maccel-rpm-builder) to ensure maccel packages are built for the exact kernel version in the Aurora base image.

## Resources

- [Aurora Documentation](https://getaurora.dev/) - Base image documentation
- [Maccel GitHub](https://github.com/Gnarus-G/maccel) - Mouse acceleration driver
- [Fedora Atomic Documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/) - Immutable OS concepts

## License

This project configuration is provided as-is for personal use. Respects licenses of Aurora (Apache 2.0), Maccel (MIT), and Fedora packages.