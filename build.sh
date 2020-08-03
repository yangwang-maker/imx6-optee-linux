#!/bin/bash

CURDIR=`pwd`
MOUNTDIR=/media/yin/rootfs

make all

# sd card partition, /dev/sdc2 mount at /media/yin/rootfs


cd ${CURDIR}/linux-imx
sudo make modules_install INSTALL_MOD_PATH=/media/yin/rootfs/ ARCH=arm CROSS_COMPILE=../aarch32/bin/arm-linux-gnueabihf-
sudo make ARCH=arm CROSS_COMPILE=../aarch32/bin/arm-linux-gnueabihf- headers_install INSTALL_HDR_PATH=/media/yin/rootfs/usr

cd ${CURDIR}/optee_client/out/export
sudo cp bin/* ${MOUNTDIR}/usr/bin
sudo cp include/* ${MOUNTDIR}/usr/include/linux
sudo cp lib/* ${MOUNTDIR}/usr/lib

sudo mkdir ${CURDIR}/lib/optee_armtz
cd ${CURDIR}/optee_examples/out
sudo cp ca/* ${MOUNTDIR}/usr/bin
sudo cp ta/* ${MOUNTDIR}/lib/optee_armtz

cd ${CURDIR}/optee_test/out
sudo cp xtest/xtest ${MOUNTDIR}/usr/bin
sudo cp ta/*.ta ${MOUNTDIR}/lib/optee_armtz

