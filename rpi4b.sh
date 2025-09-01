#!/bin/bash

# Updated Gluon Kernel Compiler for Raspberry Pi 4B (64-bit) with Linaro toolchain and modular design

# --- Configuration ---
# You can customize these variables
readonly KERNEL_ARCH="arm64"
readonly KERNEL_DEFCONFIG="bcm2711_defconfig"
readonly TOOLCHAIN_PATH="../../../toolchain/linaro"
readonly OUTPUT_DIR="output"
readonly KERNEL_DIR="raspberry_pi"
readonly KERNEL_IMAGE_NAME="kernel8.img"

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

function setup_environment() {
    KERNEL_BUILD="Gluon_Kernel_Raspberry-$(date '+%Y-%m-%d---%H-%M')"
    echo "$1" > VERSION
    VERSION=$(cat VERSION)

    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/boot/overlays"
    mkdir -p "$OUTPUT_DIR/modules"
}

function clean_kernel() {
    $cyan
    echo "Cleaning"
    $violet
    make clean
    make mrproper
}

function make_config() {
    $cyan
    echo "Making config"
    $violet
    ARCH=$KERNEL_ARCH CROSS_COMPILE="$TOOLCHAIN_PATH/bin/aarch64-linux-gnu-" make $KERNEL_DEFCONFIG
}

function compile_kernel() {
    $cyan
    echo "Making the Image-the real deal"
    $violet
    time ARCH=$KERNEL_ARCH CROSS_COMPILE="$TOOLCHAIN_PATH/bin/aarch64-linux-gnu-" make -j$(nproc) CONFIG_DEBUG_SECTION_MISMATCH=y

    time ARCH=$KERNEL_ARCH CROSS_COMPILE="$TOOLCHAIN_PATH/bin/aarch64-linux-gnu-" INSTALL_MOD_PATH="./../modules" make modules_install -j$(nproc)
}

function package_output() {
    $cyan
    echo "Packaging output"
    $violet
    cd ../
    cp "$KERNEL_DIR/arch/$KERNEL_ARCH/boot/Image" "$OUTPUT_DIR/boot/$KERNEL_IMAGE_NAME"
    cp "$KERNEL_DIR/arch/$KERNEL_ARCH/boot/dts/broadcom/*.dtb" "$OUTPUT_DIR/boot"
    cp "$KERNEL_DIR/arch/$KERNEL_ARCH/boot/dts/overlays/*.dtb*" "$OUTPUT_DIR/boot/overlays/"
    cp "$KERNEL_DIR/arch/$KERNEL_ARCH/boot/dts/overlays/README" "$OUTPUT_DIR/boot/overlays/"
}

# --- Main Script Logic ---

if [[ "$1" == "--credit" ]]; then
    show_credits
    exit 0
fi

show_header
setup_environment "$1"

set -e

# Ccache setup
export USE_CCACHE=1
export CCACHE_NLEVELS=4
ccache -M 5G

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
