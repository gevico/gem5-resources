---
title: Building the base x86-ubuntu-gpu-ml image
authors:
    - Matthew Poremba
---

This document provides instructions to create the `x86-ubuntu-gpu-ml` disk image.
This image contains Ubuntu 24.04, ROCm 7.0, amdgpu DKMS and PyTorch.
Documentation and files here are adapted from the x86-ubuntu image by Harshil Patel and Jason Lowe-Power.

## Requirements

Building requires Linux x86_64 with KVM, `curl`, `unzip`, `shasum`,
`qemu-system-x86_64`, `qemu-img`, SCons and a C++ compiler. The script downloads
Packer 1.16.1, verifies its release checksum and installs QEMU plugin 1.1.7.
The Ubuntu 24.04.2 ISO comes from Canonical's old-releases archive and is
verified against its pinned SHA-256.

Place the matching gem5 checkout beside gem5-resources, or set `GEM5_ROOT`.
The script builds the x86 m5 utility when `files/m5` is absent. A parent project
may supply its own freshly built `files/m5` before invoking this builder.

## Creating the Disk Image

The disk image is created in one step.
Run `./build.sh` in this directory to build the disk image.
This will download the packer tool, initialize packer, and build the disk image.

Building the disk image takes approximately 30 minutes depending on CPU speed and internet bandwidth.
You will see `qemu.initialize: Waiting for SSH to become available...` while the installation is running.
You can watch the installation with a VNC viewer.
See [Troubleshooting](#troubleshooting) for more information.

## Disk build output

The output directory contains `disk-image/x86-ubuntu-rocm70` and its paired
`vmlinux-rocm70`. `kernel-release` records the installed kernel selected for
extraction, and `image-packages.tsv` records the package versions.

The default disk format is raw. Use `-var disk_format=qcow2` for a compressed,
standalone QCOW2 image suitable for QEMU and CI transfer. Builder CPUs and
memory are configurable with `builder_cpus` and `builder_memory` (MiB).
`http_proxy` supplies the package-download proxy when needed. Packer's cache
and plugins are kept below `.packer-tools`, or `PACKER_TOOL_DIR` when set.
Its temporary files and plugin sockets use the short `p` subdirectory, or
`PACKER_TMP_DIR` when explicitly set. This keeps Unix socket paths within
the host's length limit.

Run `./build.sh --validate -syntax-only` to validate the HCL syntax with Packer.

You *must* pair this disk image with the extracted kernel when running GPU applications.

## Extending the Disk Image

You can mount the disk image to see what is inside or to test adding additional files.
Use the following command to mount the disk image:

```sh
mkdir mount
sudo mount -o loop,offset=2097152 disk-image/x86-ubuntu-rocm70 mount
```

Once you have tested your changes, you can add the changes to `scripts/rocm-install.sh` to preserve the changes when rebuilding the disk image.

If you want to add another ML framework, see the file `scripts/rocm-install.sh`.
The methods in that file for installing PyTorch are taken directly from [the PyTorch website](https://pytorch.org).
You could use these installation commands as examples for any other GPU related package which supports amdgpu.

## Pruning the disk image

This disk image requires approximately 42GB of space within the disk.
Some additional space is provided for users to copy data files if desired.

If you want to save space and do not need all of the packages, you may remove files from `scripts/rocm-install.sh`.
For example, if you do not require the ML frameworks, you could prune the image size down to about 16GB.

To remove PyTorch, delete or comment out the PyTorch `pip3 install` line and rebuild the disk image.

## Troubleshooting

To see what `packer` is doing, you can use the environment variable `PACKER_LOG=INFO` when running `./build.sh`.

To see what is happening while packer is running, you can connect with a VNC viewer.
The port for the VNC viewer is shown in the terminal while packer is running.

Useful documentation: <https://ubuntu.com/server/docs/install/autoinstall>
