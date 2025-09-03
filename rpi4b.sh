
#!/bin/bash
set -euo pipefail
# Updated DYANK Kernel Compiler for Raspberry Pi 4B (64-bit) with Linaro toolchain and modular design

# --- Configuration ---
# You can customize these variables
readonly KERNEL_ARCH="arm64"
readonly KERNEL_DEFCONFIG="bcm2711_defconfig"
readonly TOOLCHAIN_DIR="$HOME/toolchains"
readonly OUTPUT_DIR="$HOME/rpi4b/out"
readonly KERNEL_DIR="$HOME/rpi4b/linux_raspberryPi"
readonly KERNEL_IMAGE_NAME="kernel8.img"

# --- Linaro LLVM Variables ---
LLVM="$TOOLCHAIN_DIR/LLVM-21.1.0-Linux-X64"
TOOLCHAIN_PATH="$LLVM"

echo "Using toolchain from: ${TOOLCHAIN_PATH}"
export PATH="${TOOLCHAIN_PATH}/bin:$PATH"

# --- Toolchain / Build tools ---
# Verify clang exists
if [[ ! -x "${TOOLCHAIN_PATH}/bin/clang" ]]; then
    echo "ERROR: clang not found in ${TOOLCHAIN_PATH}/bin"
    echo "Extract the tar.xz properly and set TOOLCHAIN_PATH to the extracted folder."
    exit 1
fi

# Tell kernel build system to use LLVM toolchain
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf
export STRIP=llvm-strip

# Cross-compile for ARM64 (Raspberry Pi)
# Do NOT quote, otherwise it's a literal string
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64


# --- Colors ---
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
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
    echo "${blue} |========================================================================= "    
    echo "${cyan} |========================================================================| "
    echo "${cyan} |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DYANK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "
    echo "${cyan} |========================================================================| "    
    echo "${red} |========================================================================| "
    echo "${red} |~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DEVELOPER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "    
    echo "${cyan} |%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% yajnab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%| "
    echo "${red} |========================= Github.com/yajnab ============================| "
    echo "${red} |========================================================================| "    
    echo "${yellow}${bold} |========================================================================| "
    echo "${yellow}${bold}|======================== COMPILING DYANK KERNEL ========================| "
    echo "${yellow}${bold}|========================================================================| ${normal}"
    
}

function ensure_bin() {
    command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required tool '$1' not found in PATH"; exit 1; }
}

function setup_environment() {
    local version_text="${1:-DYANK_Kernel}"
    KERNEL_BUILD="DYANK_Kernel_Raspberry-$(date '+%Y-%m-%d---%H-%M')"
    echo "$version_text" > "${KERNEL_DIR}/VERSION" || true

    rm -rf "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}/boot/overlays"
    mkdir -p "${OUTPUT_DIR}/modules"
}

function clean_kernel() {
    echo "${cyan}Cleaning kernel tree...${normal}"
    make -C "${KERNEL_DIR}" ARCH=${KERNEL_ARCH} mrproper
}

function make_config() {
    echo "${cyan}Making defconfig: ${KERNEL_DEFCONFIG}${normal}"
    make -C "${KERNEL_DIR}" ARCH=${KERNEL_ARCH} LLVM=1 ${KERNEL_DEFCONFIG}
}

function compile_kernel() {
    echo "${cyan}Building kernel (this will take time)...${normal}"
    time make -C "${KERNEL_DIR}" -j"$(nproc)" ARCH=${KERNEL_ARCH} LLVM=1 CC=${CC} LD=${LD}

    echo "${cyan}Installing modules to temporary dir...${normal}"
    time make -C "${KERNEL_DIR}" ARCH=${KERNEL_ARCH} LLVM=1 INSTALL_MOD_PATH="${OUTPUT_DIR}/modules" modules_install -j"$(nproc)"
}

function package_output() {
    echo "${cyan}Packaging output...${normal}"
    # kernel Image
    cp "${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/Image" "${OUTPUT_DIR}/boot/${KERNEL_IMAGE_NAME}"

    # dtbs: expand glob without quotes
    cp ${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/broadcom/*.dtb "${OUTPUT_DIR}/boot/" || true

    # overlays (some files may be .dtbo)
    cp -v ${KERNEL_DIR}/arch/${KERNEL_ARCH}/boot/dts/overlays/* "${OUTPUT_DIR}/boot/overlays/" 2>/dev/null || true

    # modules are already installed into OUTPUT_DIR/modules
    echo "Modules placed in ${OUTPUT_DIR}/modules"
}
# --- Main Script Logic ---

show_header
setup_environment "${1:-default}"

set -e

# Basic checks
ensure_bin make

# Ccache setup
if command -v ccache >/dev/null 2>&1; then
    export USE_CCACHE=1
    export CCACHE_NLEVELS=4
    ccache -M 5G || true
fi

cd "$KERNEL_DIR"
clean_kernel
make_config
#clear
echo "${red}${bold} COMPILING KERNEL"
compile_kernel

package_output

#clear
echo "${red} |============================ F.I.N.I.S.H ! =============================|"
echo "${red} |==========================Flash it and Enjoy============================| "
echo "${blue} |==========Don't seek readymade goodies, try to make something new=======| "
echo "${cyan} |=================================DYANK==================================| ${normal}"
