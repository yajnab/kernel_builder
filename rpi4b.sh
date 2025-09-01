# Gluon Kernel Compiler
red='tput setaf 1'
green='tput setaf 2'
yellow='tput setaf 3'
blue='tput setaf 4'
violet='tput setaf 5'
cyan='tput setaf 6'
white='tput setaf 7'
normal='tput sgr0'
bold='setterm -bold'
date="date"
KERNEL_BUILD="Gluon_Kernel_Raspberry-`date '+%Y-%m-%d---%H-%M'`" 
echo $1 > VERSION	
VERSION='cat VERSION'
$yellow
TOOLCHAIN='../../../toolchain/linaro/bin/arm-eabi'
MODULES="./../modules"
cd ../
rm -rf output
mkdir output
mkdir output/boot
mkdir output/boot/overlays
mkdir output/modules
mkdir output/modules/lib
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
echo " Making config"
$violet
ARCH=arm CROSS_COMPILE=../../../toolchain/arm-eabi-4.9/bin/arm-eabi- make bcmrpi_gluon_defconfig
clear

$cyan
echo "Making the zImage-the real deal"
$violet
time ARCH=arm CROSS_COMPILE=../../../toolchain/arm-eabi-4.9/bin/arm-eabi- make -j64 CONFIG_DEBUG_SECTION_MISMATCH=y
time ARCH=arm CROSS_COMPILE=../../../toolchain/arm-eabi-4.9/bin/arm-eabi- INSTALL_MOD_PATH=${MODULES} make modules_install -j64
echo "Cleaning"
$violet
cd ../
cd tools_pi
cd mkimage
./mkknlimg ../../raspberry_pi/arch/arm/boot/zImage ../../output/boot/kernel.img
cd ../../
cp raspberry_pi/arch/arm/boot/dts/*.dtb output/boot
cp raspberry_pi/arch/arm/boot/dts/overlays/*.dtb* output/boot/overlays/
cp raspberry_pi/arch/arm/boot/dts/overlays/README output/boot/overlays/
clear
echo " |============================ F.I.N.I.S.H ! =============================|"
$red
echo " |==========================Flash it and Enjoy============================| "
$blue
echo " |==========Don't seek readymade goodies, try to make something new=======| "
$cyan
echo " |================================yajnab==================================| "
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
