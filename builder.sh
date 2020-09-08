#!/bin/bash
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

if [[ $1 == clean || $1 == c ]]; then
    echo "Building Clean"
    type=clean
elif [[ $1 == dirty || $1 == d ]]; then
    echo "Building Dirty"
    type=dirty
elif [[ $1 == ci ]]; then
    type=ci
else
    echo "Please specify type: clean or dirty"
    exit
fi

setup_env() {
if [ ! -d $CLANG_DIR ]; then
    echo "clang directory does not exists, cloning now..."
    git clone https://github.com/shekhawat2/clang ../toolchains/clang --depth 1
fi
if [ ! -d $GCC32_DIR ]; then
    echo "gcc32 directory does not exists, cloning now..."
    git clone git@github.com:LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git --depth 1
fi
if [ ! -d $GCC64_DIR ]; then
    echo "GCC64 directory does not exists, cloning now..."
    git clone git@github.com:LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth 1
fi
if [ ! -d $TOOLCHAIN_DIR ]; then
    echo "toolchain directory does not exists, cloning now..."
    git clone https://github.com/shekhawat2/linaro ../toolchains/tc --depth 1
fi


}

export_vars() {
export KERNEL_DIR=${PWD}
export KBUILD_BUILD_USER="S133PY"
export KBUILD_BUILD_HOST="Kali"
export ARCH=arm64
export KERNEL_DIR=${PWD}
export CLANG_DIR=${KERNEL_DIR}/../toolchains/clang
export GCC32_DIR=${KERNEL_DIR}/../toolchains/gcc-armhf
export GCC64_DIR=${KERNEL_DIR}/../toolchains/gcc-arm64
export TOOLCHAIN_DIR=${KERNEL_DIR}/../toolchains/tc
export ANYKERNEL_DIR=${KERNEL_DIR}/../anykernel
export KERNELBUILDS_DIR=${KERNEL_DIR}/../kernelbuilds
export JOBS="$(grep -c '^processor' /proc/cpuinfo)"
export PATH=${CLANG_DIR}/bin:${TOOLCHAIN_DIR}/7/bin:${TOOLCHAIN_DIR}/732/bin:${PATH}
export LD_LIBRARY_PATH=${CLANG_DIR}/lib64:$LD_LIBRARY_PATH
}

clean_up() {
echo -e "$cyan Cleaning Up $nocol"
rm -rf out
make clean && make mrproper
}

build_kernel() {

export CROSS_COMPILE=${GCC64_DIR}/bin/aarch64-linux-android-
export CROSS_COMPILE_ARM32=${GCC32_DIR}/bin/arm-linux-androideabi-
BUILD_START=$(date +"%s")
echo -e "$blue Starting $nocol"
make lavender-nethunter_defconfig  ARCH="${ARCH}"
echo -e "$yellow Making $nocol"
export PATH=${CLANG_DIR}/bin:${PATH}
time make -j"${JOBS}" \
	O=out 

BUILD_END=$(date +"%s")
DIFF=$((${BUILD_END} - ${BUILD_START}))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
}

move_files() {
if [[ ! -e ${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb ]]; then
    echo "build failed"
    exit 1
fi
echo "Movings Files"
cd ${ANYKERNEL_DIR}
rm -rf Image.gz-dtb modules/system/lib/modules/*
git reset --hard HEAD
git checkout whyredo
mv ${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb Image.gz-dtb
find ${KERNEL_DIR}/out -name "*.ko" -exec cp {} modules/system/lib/modules \;
echo -e "$blue Making Zip"
BUILD_TIME=$(date +"%Y%m%d-%T")
zip -r Team420-whyred-${BUILD_TIME} *
cd ..
mv ${ANYKERNEL_DIR}/Team420-Nethuner-whyred-${BUILD_TIME}.zip ${KERNELBUILDS_DIR}/Team420-Nethunter-whyred-${BUILD_TIME}.zip
cd ${KERNEL_DIR}
}

upload_gdrive() {
gdrive upload --share ${KERNELBUILDS_DIR}/Team420-Nethunter-whyred-${BUILD_TIME}.zip
}

export_vars
setup_env
if [[ $type == clean || $type == ci ]]; then
    clean_up
fi
build_kernel
if [[ $type == clean || $type == ci ]]; then
    move_files
    if [[ $type == clean ]]; then
        upload_gdrive
        clean_up
    elif [[ $type == ci ]]; then
        cd ${KERNELBUILDS_DIR}
        git add -A && git commit -m "${BUILD_TIME}"
        git push git@github.com:Thiviyan/Builds
    fi
fi
