# Copyright (c) 2024 Advanced Micro Devices, Inc.
# All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "= 1.1.7"
    }
  }
}

variable "image_name" {
  type    = string
  default = "x86-ubuntu-rocm70"
}

variable "ssh_password" {
  type    = string
  default = "12345"
}

variable "ssh_username" {
  type    = string
  default = "gem5"
}

variable "qemu_path" {
  type    = string
  default = "/usr/bin/qemu-system-x86_64"
}

variable "kernel_release" {
  type    = string
  default = "6.8.0-124-generic"
}

locals {
  autoinstall = merge(yamldecode(file("http/user-data")).autoinstall, {
    kernel = { package = "linux-image-${var.kernel_release}" }
  })
}

variable "disk_format" {
  type    = string
  default = "raw"
}

variable "builder_cpus" {
  type    = number
  default = 4
}

variable "builder_memory" {
  type    = number
  default = 8192
}

variable "http_proxy" {
  type    = string
  default = ""
}

source "qemu" "initialize" {
  accelerator      = "kvm"
  boot_command     = ["e<wait>",
                      "<down><down><down>",
                      "<end><bs><bs><bs><bs><wait>",
                      "autoinstall  ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
                      "<f10><wait>"
                    ]
  cpus             = var.builder_cpus
  disk_size        = "56000"
  format           = var.disk_format
  disk_compression = var.disk_format == "qcow2"
  disk_discard     = "unmap"
  headless         = "true"
  http_content = {
    "/meta-data" = file("http/meta-data")
    "/user-data" = "#cloud-config\n${yamlencode({ autoinstall = local.autoinstall })}"
  }
  iso_checksum     = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
  iso_urls         = ["https://old-releases.ubuntu.com/releases/24.04.2/ubuntu-24.04.2-live-server-amd64.iso"]
  memory           = var.builder_memory
  output_directory = "disk-image"
  qemu_binary      = "${var.qemu_path}"
  qemuargs         = [["-cpu", "host"], ["-display", "none"]]
  shutdown_command = "echo '${var.ssh_password}'|sudo -S shutdown -P now"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "60m"
  vm_name          = "${var.image_name}"
  ssh_handshake_attempts = "1000"
}

build {
  sources = ["source.qemu.initialize"]

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/run_gem5_app.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/load_amdgpu.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/serial-getty@.service"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/gem5_wmi/gem5_wmi.c"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/gem5_wmi/Makefile"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/m5"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/cosim-gpu-setup.sh"
  }

  provisioner "file" {
    destination = "/home/gem5/"
    source      = "files/cosim-gpu-setup.service"
  }

  provisioner "shell" {
    remote_folder   = "/home/gem5"
    environment_vars = [
      "http_proxy=${var.http_proxy}",
      "https_proxy=${var.http_proxy}",
      "KERNEL=${var.kernel_release}"
    ]
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    scripts         = ["scripts/rocm-install.sh"]
  }

  provisioner "file" {
    destination = "/root/roms/"
    source      = "files/mi200.rom"
  }

  provisioner "file" {
    destination = "/root/roms/"
    source      = "files/mi300.rom"
  }

  provisioner "file" {
    destination = "/usr/lib/firmware/amdgpu/mi300_discovery"
    source      = "files/mi300_discovery"
  }

  provisioner "file" {
    destination = "/usr/lib/firmware/amdgpu/mi350_discovery"
    source      = "files/mi350_discovery"
  }

  provisioner "file" {
    source      = "/home/gem5/vmlinux-gpu-ml"
    destination = "vmlinux-rocm70"
    direction   = "download"
  }

  provisioner "file" {
    source      = "/home/gem5/image-packages.tsv"
    destination = "image-packages.tsv"
    direction   = "download"
  }

  provisioner "file" {
    source      = "/home/gem5/kernel-release"
    destination = "kernel-release"
    direction   = "download"
  }

  provisioner "file" {
    source      = "/home/gem5/python-packages.json"
    destination = "python-packages.json"
    direction   = "download"
  }

  provisioner "file" {
    source      = "/home/gem5/amdgpu-module.txt"
    destination = "amdgpu-module.txt"
    direction   = "download"
  }

  provisioner "file" {
    source      = "/home/gem5/hipcc-version.txt"
    destination = "hipcc-version.txt"
    direction   = "download"
  }

  provisioner "file" {
    source      = "/etc/os-release"
    destination = "os-release"
    direction   = "download"
  }
}
