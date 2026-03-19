#!/bin/bash
set -euo pipefail

# DYANK ArkOS Kernel Builder (styled like rpi4b.sh)

SCRIPT_VERSION=1.0

# --- Configuration ---
readonly KERNEL_ARCH="arm64"
readonly TOOLCHAIN_DIR="$HOME/toolchains/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in repo root; build folders are direct children
readonly ARKOS_KERNEL_DIR="${SCRIPT_DIR}/kernel"
readonly ARKBUILD_DIR="${SCRIPT_DIR}/Arkbuild"
# --- RootFS / Image handling ---
LOOP_DEV=""
IMG_FILE=""
MOUNTED_ROOTFS=0

mkdir -p "$ARKBUILD_DIR"

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

function ensure_path_exists() {
    local target="$1"
    local label="$2"
    [ -e "$target" ] || { echo "ERROR: missing ${label}: ${target}"; exit 1; }
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
    ensure_path_exists "${TOOLCHAIN_DIR}/bin" "toolchain bin directory"
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
    mkdir -p "${ARKBUILD_DIR}/usr/bin"

    ensure_path_exists "${KERNEL_SRC}" "kernel source directory"
    echo "Using toolchain from: ${TOOLCHAIN_DIR}"
    echo "Kernel source       : ${KERNEL_SRC}"
    echo "Defconfig           : ${DEF_CONFIG}"
}

function clean_kernel() {
    cd "${KERNEL_SRC}"
    echo "${cyan}Resetting kernel config state...${normal}"
    # Avoid mrproper here: some bundled OOT drivers (esp8089) break clean targets.
    # Defconfig below is sufficient to produce a deterministic configured tree.
    rm -f .config
    cd "${SCRIPT_DIR}"
}

function reset_arkbuild_staging() {
    echo "${cyan}Resetting Arkbuild staging directory...${normal}"
    # Previous runs create root-owned content under Arkbuild via sudo operations.
    # Remove stale outputs with sudo to avoid permission-denied failures later.
    sudo rm -rf "${ARKBUILD_DIR}/lib/modules"
    sudo rm -f "${ARKBUILD_DIR}/boot/Image" "${ARKBUILD_DIR}/boot/"*.dtb \
        "${ARKBUILD_DIR}/boot/uInitrd" "${ARKBUILD_DIR}/boot/initrd.img" \
        "${ARKBUILD_DIR}/boot/initrd.img"-* "${ARKBUILD_DIR}/boot/config-"*
    mkdir -p "${ARKBUILD_DIR}/boot" "${ARKBUILD_DIR}/lib/modules" "${ARKBUILD_DIR}/usr/bin"
}


function make_config() {
    cd "${KERNEL_SRC}"
    echo "${cyan}Making defconfig: ${DEF_CONFIG}${normal}"
    CFLAGS=-Wno-deprecated-declarations make ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" "${DEF_CONFIG}"
    cd "${SCRIPT_DIR}"
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
    cd "${KERNEL_SRC}"
    echo "${cyan}Installing modules into Arkbuild (no SD / loop mounts)...${normal}"
    CFLAGS=-Wno-deprecated-declarations sudo make ARCH="${KERNEL_ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        INSTALL_MOD_PATH="${ARKBUILD_DIR}" modules_install
    cd "${SCRIPT_DIR}"
}

function setup_rootfs() {
    echo "${cyan}Setting up root filesystem from image...${normal}"
    local img_candidates=("${SCRIPT_DIR}"/*.img)

    if [ ! -e "${img_candidates[0]}" ]; then
        echo "${red}ERROR: No .img file found in ${SCRIPT_DIR}${normal}"
        exit 1
    fi

    IMG_FILE="${img_candidates[0]}"

    echo "Using image: $IMG_FILE"

    # Setup loop device with partitions
    LOOP_DEV=$(sudo losetup --find --show -Pf "$IMG_FILE")

    echo "Loop device: $LOOP_DEV"

    # Ensure mount dirs exist
    mkdir -p "${ARKBUILD_DIR}"
    mkdir -p "${ARKBUILD_DIR}/boot"
    mkdir -p "${ARKBUILD_DIR}/dev/pts" "${ARKBUILD_DIR}/proc" "${ARKBUILD_DIR}/sys"

    # Mount rootfs (p2) and boot (p1)
    sudo mount "${LOOP_DEV}p2" "${ARKBUILD_DIR}"
    # Mark rootfs as mounted immediately so trap cleanup can unmount it
    # even if mounting the boot partition fails.
    MOUNTED_ROOTFS=1
    sudo mount "${LOOP_DEV}p1" "${ARKBUILD_DIR}/boot"

    echo "${green}Root filesystem mounted successfully${normal}"
    ensure_bin qemu-aarch64-static
    sudo cp /usr/bin/qemu-aarch64-static "${ARKBUILD_DIR}/usr/bin/"
}

function package_output() {
    echo "${cyan}Packaging output into Arkbuild...${normal}"

    local mountpoint="${ARKBUILD_DIR}/boot"
    mkdir -p "${mountpoint}"

    # Copy kernel, device tree, and config into Arkbuild tree
    local KERNEL_VERSION
    KERNEL_VERSION=$(basename "$(find "${ARKBUILD_DIR}/lib/modules" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)")
    if [ -z "${KERNEL_VERSION}" ]; then
        echo "${red}ERROR: kernel modules were not installed into ${ARKBUILD_DIR}/lib/modules${normal}"
        exit 1
    fi

    sudo cp "${KERNEL_SRC}/.config" "${ARKBUILD_DIR}/boot/config-${KERNEL_VERSION}"
    sudo cp "${KERNEL_SRC}/arch/${KERNEL_ARCH}/boot/Image" "${mountpoint}/"
    sudo cp "${KERNEL_SRC}/arch/${KERNEL_ARCH}/boot/dts/rockchip/${KERNEL_DTB}" "${mountpoint}/"

    if [ "${UNIT:-}" == "rg351mp" ] || [ "${UNIT:-}" == "g350" ] || [ "${UNIT:-}" == "a10mini" ]; then
        sudo cp "/tmp/${UNIT}-uboot.dtb" "${mountpoint}/rg351mp-uboot.dtb"
        sudo rm "/tmp/${UNIT}-uboot.dtb"
    fi

    echo "${cyan}Creating uInitrd inside Arkbuild (no SD involved)...${normal}"
    sudo cp /usr/bin/qemu-aarch64-static "${ARKBUILD_DIR}/usr/bin/"

    sudo touch "${ARKBUILD_DIR}/lib/modules/${KERNEL_VERSION}/modules.builtin.modinfo"

    call_chroot "uname() { echo ${KERNEL_VERSION}; }; export -f uname; depmod ${KERNEL_VERSION}; update-initramfs -c -k ${KERNEL_VERSION}"

    sudo rm "${ARKBUILD_DIR}/usr/bin/qemu-aarch64-static"
    local initrd_source
    initrd_source=$(compgen -G "${ARKBUILD_DIR}/boot/initrd.img-*" | head -n 1 || true)
    if [ -z "${initrd_source}" ]; then
        echo "${red}ERROR: initrd image was not generated in chroot${normal}"
        exit 1
    fi
    sudo cp "${initrd_source}" "${mountpoint}/initrd.img"

    if ! command -v mkimage &>/dev/null; then
        sudo apt -y update
        sudo apt -y install u-boot-tools
    fi

    sudo mkimage -A arm64 -O linux -T ramdisk -C none -n uInitrd \
        -d "${mountpoint}/initrd.img" "${mountpoint}/uInitrd"
    sudo rm -f "${mountpoint}/initrd.img"
}

function cleanup_rootfs() {
    echo "${yellow}Cleaning up mounts...${normal}"

    set +e

    sudo umount -lf "${ARKBUILD_DIR}/dev/pts" 2>/dev/null
    sudo umount -lf "${ARKBUILD_DIR}/dev" 2>/dev/null
    sudo umount -lf "${ARKBUILD_DIR}/proc" 2>/dev/null
    sudo umount -lf "${ARKBUILD_DIR}/sys" 2>/dev/null
    sudo umount -lf "${ARKBUILD_DIR}/boot" 2>/dev/null
    if [ "${MOUNTED_ROOTFS}" -eq 1 ]; then
        sudo umount -lf "${ARKBUILD_DIR}" 2>/dev/null
    fi

    if [ -n "${LOOP_DEV}" ]; then
        sudo losetup -d "${LOOP_DEV}" 2>/dev/null
    fi

    set -e
}

function call_chroot() {
    local cmd="$1"

    sudo mount --bind /dev "${ARKBUILD_DIR}/dev"
    sudo mount --bind /dev/pts "${ARKBUILD_DIR}/dev/pts"
    sudo mount --bind /proc "${ARKBUILD_DIR}/proc"
    sudo mount --bind /sys "${ARKBUILD_DIR}/sys"

    sudo chroot "${ARKBUILD_DIR}" /bin/bash -c "$cmd"

    sudo umount -lf "${ARKBUILD_DIR}/dev/pts"
    sudo umount -lf "${ARKBUILD_DIR}/dev"
    sudo umount -lf "${ARKBUILD_DIR}/proc"
    sudo umount -lf "${ARKBUILD_DIR}/sys"
}



# --- Main Script Logic ---
trap cleanup_rootfs EXIT

show_header

# Basic checks
ensure_bin make
ensure_bin tar
ensure_bin sudo
ensure_bin losetup
ensure_env

setup_environment
reset_arkbuild_staging
setup_rootfs

clean_kernel
make_config

echo "${red}${bold} COMPILING ARKOS KERNEL${normal}"
compile_kernel
package_output

echo "${red} |============================ F.I.N.I.S.H ! =============================|"
echo "${red} |======================= Copy from Arkbuild and Enjoy ===================| "
echo "${blue} |==========Don't seek readymade goodies, try to make something new=======| "
echo "${cyan} |=================================DYANK==================================| ${normal}"
