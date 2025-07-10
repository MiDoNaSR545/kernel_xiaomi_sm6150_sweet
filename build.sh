#!/bin/bash

set -e

# Ask for AOSP or OEM
read -p "Enter build type (aosp/oem): " buildtype
buildtype_lower=$(echo "$buildtype" | tr '[:upper:]' '[:lower:]')

# Ask for KernelSU
read -p "Include KernelSU? (y/n): " ksu_response
ksu_lower=$(echo "$ksu_response" | tr '[:upper:]' '[:lower:]')

# Set prefix based on build type
if [[ "$buildtype_lower" == "aosp" ]]; then
    zip_prefix="AOSP"
else
    zip_prefix="MIUI-OOS"
fi

# Add KSU to prefix if selected
if [[ "$ksu_lower" == "y" || "$ksu_lower" == "yes" ]]; then
    echo -e "\n🔧 Setting up KernelSU..."
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main
    zip_prefix="${zip_prefix}_KSU"
fi

# Final ZIP name
ZIPNAME="${zip_prefix}-MeMeDo-sweet_k6a-$(date '+%Y%m%d').zip"


# Download Clang and GCC toolchains
if [ ! -d clang ]; then
    mkdir clang
    curl -LO https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r547379.tar.gz
    tar -xf clang-r547379.tar.gz -C clang/
    rm clang-r547379.tar.gz
fi

if [ ! -d gcc64 ]; then
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
fi

if [ ! -d gcc32 ]; then
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32
fi

# Setup environment
export ARCH=arm64
export PATH="${PWD}/clang/bin:${PWD}/gcc64/bin:${PWD}/gcc32/bin:${PATH}"
export KBUILD_BUILD_USER=build-user
export KBUILD_BUILD_HOST=build-host
export KBUILD_COMPILER_STRING="${PWD}/clang"
export LLVM=1 
export LLVM_IAS=1
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_COMPAT=arm-linux-androideabi-

# Build directory

# Kernel compilation
make O=out sweet_defconfig
make -j$(nproc --all) O=out CC=clang 2>&1 | tee build.log

# Save config for reference
cp out/.config out/sweet_defconfig.txt

# Check output
KERNEL_IMG="out/arch/arm64/boot/Image.gz"
DTBO_IMG="out/arch/arm64/boot/dtbo.img"
DTB_IMG="out/arch/arm64/boot/dtb.img"

if [[ ! -f "$KERNEL_IMG" || ! -f "$DTBO_IMG" || ! -f "$DTB_IMG" ]]; then
    echo -e "\n❌ Build failed. Missing output image(s)."
    exit 1
fi

