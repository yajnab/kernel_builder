#!/bin/bash

# Updated Gluon Kernel Compiler for Raspberry Pi 4B (64-bit)

# Colors
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
violet=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
normal=$(tput sgr0)
bold=$(setterm -bold)

# Naming convention for the new kernel
KERNEL_BUILD="Gluon_Kernel_Raspberry-`date '+%Y-%m-%d---%H-%M'`" 
echo $1 > VERSION
VERSION=$(cat VERSION)

# Variables for the new build environment
TOOLCHAIN='../../../toolchain/aarch64-linux-gnu'
MODULES="./../modules"

cd ../
rm -rf output
mkdir -p output/boot/overlays
mkdir -p output/modules/lib

cd raspberry_pi
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

set -e

export USE_CCACHE=1
export CCACHE_NLEVELS=4
ccache -M 5G

$cyan
echo "Cleaning"
$violet
make clean
make mrproper

$cyan
echo "Making config"
$violet
# Use ARCH=arm64 and bcm2711_defconfig for Raspberry Pi 4B
ARCH=arm64 CROSS_COMPILE=$TOOLCHAIN/bin/aarch64-linux-gnu- make bcm2711_defconfig
clear

$cyan
echo "Making the Image-the real deal"
$violet
# Cross-compile the kernel image
time ARCH=arm64 CROSS_COMPILE=$TOOLCHAIN/bin/aarch64-linux-gnu- make -j$(nproc) CONFIG_DEBUG_SECTION_MISMATCH=y

# Install modules
time ARCH=arm64 CROSS_COMPILE=$TOOLCHAIN/bin/aarch64-linux-gnu- INSTALL_MOD_PATH=${MODULES} make modules_install -j$(nproc)

echo "Cleaning"
$violet
cd ../
cd tools_pi
cd mkimage
# Use the new kernel image name for 64-bit builds on Pi 4
./mkknlimg ../../raspberry_pi/arch/arm64/boot/Image ../../output/boot/kernel8.img
cd ../../
cp raspberry_pi/arch/arm64/boot/dts/broadcom/*.dtb output/boot
cp raspberry_pi/arch/arm64/boot/dts/overlays/*.dtb* output/boot/overlays/
cp raspberry_pi/arch/arm64/boot/dts/overlays/README output/boot/overlays/
clear
echo " |============================ F.I.N.I.S.H ! =============================|"
$red
echo " |==========================Flash it and Enjoy============================| "
$blue
echo " |==========Don't seek readymade goodies, try to make something new=======| "
$cyan
echo " |==============================Gluon Works===============================| "
$red
echo " |================================Credits=================================| "
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
echo " |========================================================================| "
$normal
