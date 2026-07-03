# Bootlegger Kernel - CI Build System

Automated kernel build system powered by GitHub Actions.  
Originally built for **davinci** (Mi 9T / Redmi K20, 4.14 kernel), but designed to work with **any device and kernel source** (tested on 4.9 and 4.19 too).

## Features

- **KernelSU** — Optional KernelSU integration with automatic patching
- **SuSFS** — Optional [SuSFS](https://gitlab.com/simonpunk/susfs4ksu) patching for supported kernel versions (4.9, 4.14, 4.19, 5.4)
- **Custom KSU Manager** — Build a custom KernelSU Manager APK, signed with your own keystore

## Quick Start

1. **Fork** this repository
2. Edit the `Changable Data` section in [`main.sh`](main.sh) (see [Configuration](#configuration))
3. Go to **Actions → CI Build → Run workflow**
4. Choose your build options (these override the variables in `main.sh`)
5. Built files will appear under **Releases** in your repository

### Build Options

When triggering the CI manually, you can choose:

| Input | Description | Default |
|---|---|---|
| `Build_Kernel` | `KSU`, `NonKSU`, or `KSU & NonKSU` | `KSU & NonKSU` |
| `KSU_Manager_Non_GKI` | Build a custom KSU Manager APK | `false` |
| `Clang_Repo` | Clang toolchain repo (`Owner/reponame`) | `Neutron-Toolchains/clang-build-catalogue` |
| `Clang_Tag` | Clang release tag | `latest` |
| `Clang_Args` | Compiler arguments | *(see `main.sh`)* |
| `Kernel_Git` | `.git` URL to your kernel source | `github.com/silvzr/bootlegger_kernel_archive.git` |
| `Kernel_Branch` | Branch to build from | `pos16` |
| `AnyKernel3_Git` | `.git` URL to your AnyKernel3 repo | `github.com/silvzr/AnyKernel3.git` |
| `AnyKernel3_Branch` | AnyKernel3 branch | `master` |
| `Device_Code` | Device codename (e.g. `davinci`) | `davinci` |
| `Device_Defconfig` | Defconfig file (e.g. `davinci_defconfig`) | `davinci_defconfig` |
| `Common_Defconfig` | Optional common/shared defconfig | *(empty)* |
| `os` | Runner OS | `ubuntu-latest` |

## Configuration

All configurable variables live in the `Changable Data` section at the top of [`main.sh`](main.sh).  
Use the format `VARIABLE="value"`.

```
# Kernel
KERNEL_NAME          Name of your kernel
KERNEL_GIT           .git URL to your kernel repo
KERNEL_BRANCH        Branch of your kernel repo

# KernelSU
KERNELSU_REPO        KernelSU repo (Owner/reponame)    default: "backslashxx/KernelSU"
KERNELSU_BRANCH      KernelSU branch                   default: "master"
KSU_ENABLED          "true" or "false"                 default: "false"

# KernelSU Custom Manager
MANAGER_EXPECTED_SIZE   Expected APK size (for verification)
MANAGER_EXPECTED_HASH   Expected APK hash (for verification)

# Anykernel3
ANYKERNEL3_GIT       .git URL to your AnyKernel3 repo
ANYKERNEL3_BRANCH    AnyKernel3 branch                 default: "master"

# Build
DEVICE_CODE          Device codename
DEVICE_DEFCONFIG     Defconfig file for the device
COMMON_DEFCONFIG     Optional common/shared defconfig
DEVICE_ARCH          Architecture path                  default: "arch/arm64"

# Clang
CLANG_REPO           Clang repo (Owner/reponame)       default: "Neutron-Toolchains/clang-build-catalogue"
CLANG_TAG            Clang release tag                 default: "latest"
CLANG_ARGS           Compiler/linker flags             (see main.sh for defaults)
```

## KSU Manager Setup

To build a custom KernelSU Manager APK, you need to:

1. **Fork** [KernelSU](https://github.com/tiann/KernelSU)
2. **Edit** [`build-ksu-manager.yml`](.github/workflows/build-ksu-manager.yml) and [`ksud.yml`](.github/workflows/ksud.yml) — change the `repository:` field from `silvzr/KernelSU` to your own fork
3. **Set `MANAGER_EXPECTED_SIZE` and `MANAGER_EXPECTED_HASH`** in [`main.sh`](main.sh) to match your custom Manager APK for verification
4. **Add the following secrets** to your repository (**Settings → Secrets and variables → Actions**):

| Secret | Description |
|---|---|
| `KEYSTORE` | Base64-encoded keystore file (`.jks`) |
| `KEYSTORE_PASSWORD` | Password for the keystore |
| `KEY_ALIAS` | Key alias within the keystore |
| `KEY_PASSWORD` | Password for the key |
| `SYNC_UPSTREAM_KSU` | *(Optional)* A personal access token to auto-sync (rebase) your KernelSU fork with upstream before building |

> **Tip:** To base64-encode your keystore: `base64 -w 0 your-keystore.jks`

## Patches

Patches are managed through a [submodule](https://github.com/silvzr/bootlegger_kernel/tree/patches-dev) (`patches/`) and are automatically applied during the build.

The patch system includes:

- **KernelSU backport patches** — Hook patches for kernel versions 4.4, 4.9, 4.14, 4.19, and 5.4
- **SuSFS patches** — Filesystem-level stealth patches for kernel versions 4.9, 4.14, 4.19, and 5.4
- **`path_umount` backport** — Required for KernelSU on older kernels
- **Safe mode patch** — KernelSU safe mode support
- **`strip_out_extraversion` patch** — Keeps the kernel uname clean

## Environment

The [`env.sh`](env.sh) script sets up the build environment on Ubuntu runners, installing all required build dependencies (GCC cross-compilers, Clang, LLVM, LLD, etc.).

## License

[MIT](LICENSE)
