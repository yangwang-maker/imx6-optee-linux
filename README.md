# imx6q sabresd Linux Optee 

```
cd ~
mkdir imx6-optee
cd imx6-optee
```

## toolchain

```
wget http://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/arm-linux-gnueabihf/gcc-linaro-6.5.0-2018.12-x86_64_arm-linux-gnueabihf.tar.xz
tar -xvf gcc-linaro-6.5.0-2018.12-x86_64_arm-linux-gnueabihf.tar.xz
mv gcc-linaro-6.5.0-2018.12-x86_64_arm-linux-gnueabihf aarch32
```

## uboot

```
git clone https://source.codeaurora.org/external/imx/uboot-imx -b imx_v2018.03_4.14.78_1.0.0_ga
```

## Linux

```
git clone https://source.codeaurora.org/external/imx/linux-imx/ -b imx_4.14.78_1.0.0_ga
```

## optee

```
git clone https://source.codeaurora.org/external/imx/imx-optee-os -b imx_4.14.78_1.0.0_ga
git clone https://github.com/OP-TEE/optee_client -b 3.2.0
git clone https://github.com/OP-TEE/optee_test -b 3.2.0
git clone https://github.com/linaro-swg/optee_examples -b 3.2.0
```

## make

```
make all    //编译所有
make linux-imx   //只编译linux
```

## rootfs

```
wget https://rcn-ee.com/rootfs/eewiki/minfs/ubuntu-18.04.3-minimal-armhf-2020-02-10.tar.xz
tar -xvf ubuntu-18.04.3-minimal-armhf-2020-02-10.tar.xz
```

## SD Card

1. 分区

   按照sdCardParted.txt 操作, 结果如下:

   ```
   $ sudo mkfs.vfat /dev/sdc1
   $ sudo fatlabel /dev/sdc1 BOOT
   $ sudo mkfs.ext4 -L rootfs /dev/sdc2
   
   $ lsblk
   sdc      8:32   1   7.4G  0 disk 
   ├─sdc1   8:33   1   490M  0 part /media/yin/9582-02E1
   └─sdc2   8:34   1   6.8G  0 part /media/yin/rootfs
   $ sudo fdisk /dev/sdc
   Device     Boot   Start      End  Sectors  Size Id Type
   /dev/sdc1         20480  1024000  1003521  490M 83 Linux
   /dev/sdc2       1228800 15523839 14295040  6.8G 83 Linux
   ```

2. 烧写

   ```sh
   cd out
   sudo dd if=u-boot-dtb.imx of=/dev/sdc bs=512 seek=2 conv=sync conv=notrunc
   // /dev/sdc1分区挂载在/media/yin/BOOT                          /dev/sdc2分区挂载在/media/yin/rootfs
   cp zImage imx6q-sabresd.dtb uTee-6qsdb /media/yin/BOOT   
   
   cd ../ubuntu-18.04.3-minimal-armhf-2020-02-10
   sudo tar xvf  armhf-rootfs-ubuntu-bionic.tar -C /media/yin/rootfs
   
   cd ../linux-imx
   sudo make modules_install INSTALL_MOD_PATH=/media/yin/rootfs/ ARCH=arm CROSS_COMPILE=../aarch32/bin/arm-linux-gnueabihf-
   sudo make ARCH=arm CROSS_COMPILE=../aarch32/bin/arm-linux-gnueabihf- headers_install INSTALL_HDR_PATH=/media/yin/rootfs/usr
   
// rootfs 配置, 
   $ cd /media/yin/rootfs
   $ sudo vim etc/network/interface //添加
   auto lo  
   iface lo inet loopback  
   auto eth0  
   iface eth0 inet dhcp
   
   ```
   
   3. optee
   
   ```shell
   CURDIR=`pwd`
   MOUNTDIR=/media/yin/rootfs
   
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
   ```
   
   ## 启动
   
   第一次启动时, uboot 命令行输入:
   
   \> setenv fdt_addr 0x28000000
   
   \> setenv tee_addr 0x30000000
   
   \> saveenv
   
   \> reset
   
   ## 配置
   
   进入开发板命令行:
   
   $ sudo su
   
   \# ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
   
   \# cp /etc/apt/source.list /etc/apt/source.list.bak
   
   \# vi /etc/apt/source.list
   
   删除所有: 光标在第一行 dG        全局替换:           :%s/ubuntu/ubuntu-ports/
   
   内容修改为:
   
   ```
   deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic main restricted unn
   iverse multiverse
   # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic main restricc
   ted universe multiverse
   deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-updates main restrr
   icted universe multiverse
   # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-updates mainn
    restricted universe multiverse
   deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-backports main ress
   tricted universe multiverse
   # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-backports maa
   in restricted universe multiverse
   deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-security main restt
   ricted universe multiverse
   # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-security maii
   n restricted universe multiverse
   ```
   
   ## 测试
   
   ```
   $ sudo tee-supplicant &
   $ sudo optee_example_hello_world
            .....
   	I/TA:  Hello World!                                                                   
   	Invoking TA to increment 42                                                           
   	F/TC:0 trace_syscall:128 syscall #1 (syscall_log)                                     
   	D/TA:  inc_value:105 has been called                                                  
   	F/TC:0 trace_syscall:128 syscall #1 (syscall_log)                                     
   	I/TA:  Got value: 42 from NW                                                          
   	F/TC:0 trace_syscall:128 syscall #1 (syscall_log)                                     
   	I/TA:  Increase value to: 43                                                          
   	TA incremented value to 43                                                            
   	D/TC:0 tee_ta_close_session:380 tee_ta_close_session(0x1405b390)                      
   	D/TC:0 tee_ta_close_session:399 Destroy session                                       
   	F/TC:0 trace_syscall:128 syscall #1 (syscall_log)                                     
   	I/TA:  Goodbye!
   	
   想不使用 sudo, 可以sudo chmod 777 /dev/tee*  即tee device的UGO中 other 改为 7	
   ```
   
   **成功!!!!**
   
   进一步添加图形界面,我就不折腾了,参考[这里](https://community.nxp.com/docs/DOC-330147)

## 参考

[imx6q CAAM in optee](https://github.com/OP-TEE/optee_os/issues/2701)

[i.MX6q SABRE Board for Smart Devices](https://www.digikey.com/eewiki/display/linuxonarm/i.MX6q+SABRE+Board+for+Smart+Devices)

 [Installing Ubuntu Rootfs on NXP i.MX6 boards](https://community.nxp.com/docs/DOC-330147)