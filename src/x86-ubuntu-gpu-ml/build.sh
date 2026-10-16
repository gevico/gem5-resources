#!/bin/bash

# Copyright (c) 2024 The Regents of the University of California.
# SPDX-License-Identifier: BSD-3-Clause

set -euo pipefail

PACKER_VERSION="1.16.1"
tool_dir="${PACKER_TOOL_DIR:-$PWD/.packer-tools}"
export TMPDIR="${PACKER_TMP_DIR:-$PWD/p}"
mkdir -p "$TMPDIR" "$tool_dir/cache" "$tool_dir/plugins"
export PACKER_CACHE_DIR="$tool_dir/cache"
export PACKER_PLUGIN_PATH="$tool_dir/plugins"
export CHECKPOINT_DISABLE=1

case "$(uname -s)" in
    Linux) packer_os=linux ;;
    Darwin) packer_os=darwin ;;
    *) echo "Unsupported Packer host OS" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64) packer_arch=amd64 ;;
    aarch64 | arm64) packer_arch=arm64 ;;
    *) echo "Unsupported Packer host architecture" >&2; exit 1 ;;
esac

if [ ! -x ./packer ] ||
    [ "$(./packer version | head -n 1)" != "Packer v${PACKER_VERSION}" ]; then
    archive="packer_${PACKER_VERSION}_${packer_os}_${packer_arch}.zip"
    release="https://releases.hashicorp.com/packer/${PACKER_VERSION}"
    curl --fail --location --retry 3 "$release/$archive" -o "$tool_dir/$archive"
    sums="packer_${PACKER_VERSION}_SHA256SUMS"
    curl --fail --location --retry 3 "$release/$sums" -o "$tool_dir/$sums"
    (
        cd "$tool_dir"
        grep -F "  $archive" "$sums" | shasum -a 256 --check --status
    )
    unzip -o "$tool_dir/$archive" packer -d .
fi

# Install the needed plugins
./packer init x86-ubuntu-gpu-ml.pkr.hcl

if [ "${1:-}" = "--validate" ]; then
    shift
    exec ./packer validate "$@" x86-ubuntu-gpu-ml.pkr.hcl
fi

if [ ! -f files/m5 ]; then
    gem5_root="${GEM5_ROOT:-$(cd ../../.. && pwd)/gem5}"
    test -d "$gem5_root/util/m5" || {
        echo "Set GEM5_ROOT to the matching gem5 source checkout" >&2
        exit 1
    }
    scons -C "$gem5_root/util/m5" build/x86/out/m5
    cp "$gem5_root/util/m5/build/x86/out/m5" files/m5
fi

# Build the image - Pass command line options from this script to build
# command. This can be used to set variable such as qemu path.
exec ./packer build "$@" x86-ubuntu-gpu-ml.pkr.hcl
