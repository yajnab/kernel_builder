
#!/bin/bash
set -euo pipefail
# Updated Gluon Kernel Compiler for Raspberry Pi 4B (64-bit) with Linaro toolchain and modular design

# --- Configuration ---
# You can customize these variables
readonly KERNEL_ARCH="arm64"
readonly KERNEL_DEFCONFIG="bcm2711_defconfig"
readonly TOOLCHAIN_DIR="$HOME/toolchains"
readonly OUTPUT_DIR="$HOME/rpi4b/out"
readonly KERNEL_DIR="$HOME/rpi4b/linux_raspberryPi"
readonly KERNEL_IMAGE_NAME="kernel8.img"

#---Linaro LLVM Variables--
export LLVM='$TOOLCHAIN_DIR/LLVM-21.1.0-Linux-ARM64'
export PATH=$LLVM:$PATH
TOOLCHAIN_PATH='$LLVM'
export PATH=$TOOLCHAIN_PATH/bin:$PATH
# --- Toolchain / Build tools ---
# Prefer explicit full path to LLVM bin dir
if [[ ! -x "${TOOLCHAIN_PATH}/bin/clang" ]]; then
    echo "ERROR: clang not found in ${TOOLCHAIN_PATH}/bin"
    echo "Extract the tar.xz and set TOOLCHAIN_PATH to the extracted folder."
    exit 1
fi



# Tell kernel make to use clang/ld.lld
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf
export STRIP=llvm-strip

# Cross compile target triple for aarch64
export CROSS_COMPILE='$TOOLCHAIN_PATH/bin/aarch64-linux-gnu-'

# --- Colors ---
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
violet=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
normal=$(tput sgr0)
bold=$(setterm -bold)

# --- Functions ---
function show_header() {
    $blue
    echo " |========================================================================| "
    echo " |*************************** GLUON KERNEL *******************************| "
    echo " |========================================================================= "
    $cyan
    echo " |========================================================================| "
    echo " |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Gluon Works ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "
    echo " |========================================================================| "
    $red
    echo " |========================================================================| "
    echo " |~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DEVELOPER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "
    $cyan
    echo " |%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Yajnab %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%| "
    $red
    echo " |=========================== XDA-DEVELOPERS =============================| "
    echo " |========================= Github.com/Yajnab ============================| "
    echo " |========================================================================| "
    $yellow
    $bold
    echo " |========================================================================| "
    echo " |======================== COMPILING GLUON KERNEL ========================| "
    echo " |========================================================================| "
    $normal
}

function show_credits() {
    $red
    echo " |========================================================================| "
    echo " |================================CREDITS=================================| "
    $normal
    echo " |~~~~~~~~~~~~~~~~~~~~~~Dr.Nachiketa Bandyopadhyay(My Father)~~~~~~~~~~~~~| "
    echo " |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~My Computer~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| "
    echo " |~~~~~~~~~~~~~~~~~~~~~~~~~Samsung Galaxy Fit(Beni)~~~~~~~~~~~~~~~~~~~~~~~| "
    echo " |========================================================================| "
    $violet
    echo " |========================================================================| "
    echo " |********************Vishwanath Patil(He taught me all)******************| "
    echo " |****************************Aditya Patange(Adipat)**********************| "
    echo " |************************Sarthak Acharya(sakindia123)********************| "
    echo " |****************************Teguh Soribin(tjstyle)**********************| "
    echo " |****************************Yanuar Harry(squadzone)*********************| "
    echo " |*********************************faux123********************************| "
    echo " |****************************Linux Torvalds(torvalds)********************| "
    echo " |**************************Mark Shuttleworth (Canonical)*****************| "
    echo " |*************************Alan Cox (Linux Kernel)************************| "
    echo " |**************************Richard Stallman (GNU)************************| "
    echo " |***********************Andrew S. Tanenbaum (MINIX)**********************| "
    echo " |************************Ken Thompson (Unix)*****************************| "
    echo " |**************************Dennis Ritchie (Unix)*************************| "
    echo " |**************************Rob Pike (Plan 9)*****************************| "
    echo " |***********************Bill Gates (Microsoft)***************************| "
    echo " |************************Steve Jobs (Apple)******************************| "
    echo " |******************Dr. Hans-Juergen (Embedded Systems Guru)**************| "
    echo " |**************************Erich Gamma (Design Patterns)*****************| "
    echo " |***********************James Gosling (Java)*****************************| "
    echo " |*********************Bjarne Stroustrup (C++)****************************| "
    echo " |*********************Guido van Rossum (Python)**************************| "
    echo " |*********************Tim Berners-Lee (World Wide Web)*******************| "
    echo " |********************Vint Cerf and Bob Kahn (Internet)*******************| "
    echo " |***********************Grace Hopper (COBOL)*****************************| "
    echo " |**********************Linus Torvalds (Git)******************************| "
    echo " |========================================================================| "
    $normal
}

function ensure_bin() {
    command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required tool '$1' not found in PATH"; exit 1; }
}

function setup_environment() {
    local version_text="${1:-Gluon_Kernel}"
    KERNEL_BUILD="Gluon_Kernel_Raspberry-$(date '+%Y-%m-%d---%H-%M')"
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
    make -C "${KERNEL_DIR}" ARCH=${KERNEL_ARCH} CROSS_COMPILE=${CROSS_COMPILE} ${KERNEL_DEFCONFIG}
}

function compile_kernel() {
    echo "${cyan}Building kernel (this will take time)...${normal}"
    time make -C "${KERNEL_DIR}" -j"$(nproc)" ARCH=${KERNEL_ARCH} CROSS_COMPILE=${CROSS_COMPILE} CC=${CC} LD=${LD}

    echo "${cyan}Installing modules to temporary dir...${normal}"
    time make -C "${KERNEL_DIR}" ARCH=${KERNEL_ARCH} CROSS_COMPILE=${CROSS_COMPILE} INSTALL_MOD_PATH="${OUTPUT_DIR}/modules" modules_install -j"$(nproc)"
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

if [[ "$1" == "--credit" ]]; then
    show_credits
    exit 0
fi

show_header
setup_environment "$1"

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
clear
compile_kernel

package_output

clear
echo " |============================ F.I.N.I.S.H ! =============================|"
$red
echo " |==========================Flash it and Enjoy============================| "
$blue
echo " |==========Don't seek readymade goodies, try to make something new=======| "
$cyan
echo " |==============================Gluon Works===============================| "
$normal
