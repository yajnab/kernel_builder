#!/bin/bash
set -euo pipefail

# DYANK ArkOS Kernel Builder (styled like rpi4b.sh)

SCRIPT_VERSION=1.0

# --- Configuration ---
readonly KERNEL_ARCH="arm64"
readonly TOOLCHAIN_DIR="$HOME/toolchains/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu"
# Script is in repo root; build folders are direct children
readonly ARKOS_KERNEL_DIR="kernel"
readonly ARKBUILD_DIR="Arkbuild"


mkdir -p "$ARKBUILD_DIR"
rm -rf "$ARKBUILD_DIR"/*

echo "Building inside: $ARKBUILD_DIR"


# --- Colors ---
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
violet=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
normal=$(tput sgr0)
bold=$(tput bold)

# --- Functions ---
function show_header() {
    echo "${blue} |========================================================================| "
    echo "${blue} |*************************** DYANK KERNEL *******************************| "
    echo "${blue} |========================================================================| "
    echo "${cyan} |========================================================================| "
    echo "${cyan} |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DYANK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "
    echo "${cyan} |========================================================================| "
    echo "${red} |========================================================================| "
    echo "${red} |~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DEVELOPER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "
    echo "${cyan} |%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% yajnab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%| "
    echo "${red} |========================= Github.com/yajnab ============================| "
    echo "${red} |========================================================================| "
    echo "${yellow}${bold} |========================================================================| "
    echo "${yellow}${bold}|======================= COMPILING DYANK KERNEL =========================| "
    echo "${yellow}${bold}|========================================================================| ${normal}"
}

function ensure_bin() {
    command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required tool '$1' not found in PATH"; exit 1; }
}

function ensure_env() {
    # Default to rg351p / rk3326 if not provided
    : "${UNIT:=rg351p}"
    : "${CHIPSET:=rk3326}"

    echo "Target UNIT   : ${UNIT}"
    echo "Target CHIPSET: ${CHIPSET}"
}

function setup_environment() {
    echo "${cyan}Setting up environment for ArkOS kernel build...${normal}"

    # Toolchain / build vars
    export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
    export ARCH="${KERNEL_ARCH}"
    export CROSS_COMPILE=aarch64-linux-gnu-

    # Kernel source / config (ArkOS style)
    if [ "${UNIT:-}" == "rgb10" ] || [ "${UNIT:-}" == "rk2020" ]; then
        KERNEL_SRC="odroidgoA-4.4.y"
        DEF_CONFIG="odroidgoa_tweaked_defconfig"
        SCREEN_ROTATION="3"
        if [ "${UNIT:-}" == "rgb10" ]; then
            KERNEL_DTB="${CHIPSET}-odroidgo2-linux-v11.dtb"
        else
            KERNEL_DTB="${CHIPSET}-odroidgo2-linux.dtb"
        fi
    else
        KERNEL_SRC="${ARKOS_KERNEL_DIR}"
        DEF_CONFIG="rg351p_tweaked_defconfig"
        SCREEN_ROTATION="0"
        KERNEL_DTB="${CHIPSET}-${UNIT}-linux.dtb"
    fi

    # Output / staging
    mkdir -p "${ARKBUILD_DIR}/boot"
    mkdir -p "${ARKBUILD_DIR}/lib/modules"

    echo "Using toolchain from: ${TOOLCHAIN_DIR}"
    echo "Kernel source       : ${KERNEL_SRC}"
    echo "Defconfig           : ${DEF_CONFIG}"
}

function clean_kernel() {
    cd "${KERNEL_SRC}"
    echo "${cyan}Cleaning kernel tree...${normal}"
    # Some out-of-tree drivers (e.g. esp8089) expect a .config to exist in the
    # configured kernel tree. Create a temporary empty .config if missing so
    # mrproper can run cleanly; it will remove it anyway.
    if [ ! -f .config ]; then
        touch .config
    fi
    CFLAGS=-Wno-deprecated-declarations make ARCH="${KERNEL_ARCH}" mrproper || true
    cd ..
}


function make_config() {
    cd "${KERNEL_SRC}"
    echo "${cyan}Making defconfig: ${DEF_CONFIG}${normal}"
    CFLAGS=-Wno-deprecated-declarations make ARCH="${KERNEL_ARCH}" "${DEF_CONFIG}"
    cd ..
}

function compile_kernel() {
    cd "${KERNEL_SRC}"
    echo "${cyan}Building kernel (this will take time)...${normal}"

    CFLAGS=-Wno-deprecated-declarations \
        make -j"$(nproc)" ARCH="${KERNEL_ARCH}" \
        CROSS_COMPILE="${CROSS_COMPILE}" modules_prepare

    CFLAGS=-Wno-deprecated-declarations \
        make -j"$(nproc)" ARCH="${KERNEL_ARCH}" \
        CROSS_COMPILE="${CROSS_COMPILE}" Image dtbs modules
    cd ..
    cd "${KERNEL_SRC}"
    echo "${cyan}Installing modules into Arkbuild (no SD / loop mounts)...${normal}"
    CFLAGS=-Wno-deprecated-declarations sudo make ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        INSTALL_MOD_PATH="${ARKBUILD_DIR}" modules_install
    cd ..
}

function package_output() {
    echo "${cyan}Packaging output into Arkbuild...${normal}"

    local mountpoint="${ARKBUILD_DIR}/boot"
    mkdir -p "${mountpoint}"

    # Copy kernel, device tree, and config into Arkbuild tree
    local KERNEL_VERSION
    KERNEL_VERSION=$(basename "$(ls "${ARKBUILD_DIR}/lib/modules")")

    sudo cp "${KERNEL_SRC}/.config" "${ARKBUILD_DIR}/boot/config-${KERNEL_VERSION}"
    sudo cp "${KERNEL_SRC}/arch/${KERNEL_ARCH}/boot/Image" "${mountpoint}/"
    sudo cp "${KERNEL_SRC}/arch/${KERNEL_ARCH}/boot/dts/rockchip/${KERNEL_DTB}" "${mountpoint}/"

    if [ "${UNIT:-}" == "rg351mp" ] || [ "${UNIT:-}" == "g350" ] || [ "${UNIT:-}" == "a10mini" ]; then
        sudo cp "/tmp/${UNIT}-uboot.dtb" "${mountpoint}/rg351mp-uboot.dtb"
        sudo rm "/tmp/${UNIT}-uboot.dtb"
    fi

    echo "${cyan}Creating uInitrd inside Arkbuild (no SD involved)...${normal}"
    sudo cp /usr/bin/qemu-aarch64-static "${ARKBUILD_DIR}/usr/bin/"

    KERNEL_VERSION=$(basename "$(find "${ARKBUILD_DIR}/lib/modules" -maxdepth 1 -mindepth 1 -type d)")
    sudo touch "${ARKBUILD_DIR}/lib/modules/${KERNEL_VERSION}/modules.builtin.modinfo"

    call_chroot "uname() { echo ${KERNEL_VERSION}; }; export -f uname; depmod ${KERNEL_VERSION}; update-initramfs -c -k ${KERNEL_VERSION}"

    sudo rm "${ARKBUILD_DIR}/usr/bin/qemu-aarch64-static"
    sudo cp "${ARKBUILD_DIR}/boot/initrd.img"-* "${mountpoint}/initrd.img"

    if ! command -v mkimage &>/dev/null; then
        sudo apt -y update
        sudo apt -y install u-boot-tools
    fi

    sudo mkimage -A arm64 -O linux -T ramdisk -C none -n uInitrd \
        -d "${mountpoint}/initrd.img" "${mountpoint}/uInitrd"
    sudo rm -f "${mountpoint}/initrd.img"
}

# --- Main Script Logic ---
show_header

# Basic checks
ensure_bin make
ensure_env

setup_environment
clean_kernel
make_config

echo "${red}${bold} COMPILING ARKOS KERNEL${normal}"
compile_kernel
package_output

echo "${red} |============================ F.I.N.I.S.H ! =============================|"
echo "${red} |======================= Copy from Arkbuild and Enjoy ===================| "
echo "${blue} |==========Don't seek readymade goodies, try to make something new=======| "
echo "${cyan} |=================================DYANK==================================| ${normal}"
