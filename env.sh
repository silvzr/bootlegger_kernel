#!/usr/bin/env bash

UBUNTU_VERSION=$(lsb_release -sr)

# Remove FireFox
apt remove firefox && apt autoremove

# Environment Setup
apt-get update && apt-get upgrade -y build-essential pkg-config git bc bison flex libssl-dev libelf-dev libncurses-dev python3 python3-distutils python3-venv file dwarves xz-utils zstd lz4 cpio tar rsync gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-dev-arm64-cross clang lld llvm

# Install python2 if Ubuntu version is lower than 24.04
if [[ $UBUNTU_VERSION != "24.04" ]]; then
    apt-get install -y python2
fi
