
CURDIR=$(shell pwd)
CROSS_COMPILE=$(CURDIR)/aarch32/bin/arm-linux-gnueabihf-

ARCH=arm
PLATFORM=imx-mx6qsabresd
COMPILE_NS_USER= 32
LOCALVERSION=4.14.78

OUT_PATH			?=$(CURDIR)/out
BUILD_PATH			?= $(CURDIR)/build
UBOOT_PATH          ?= $(CURDIR)/uboot-imx
LINUX_PATH			?= $(CURDIR)/linux-imx
OPTEE_OS_PATH			?= $(CURDIR)/imx-optee-os
OPTEE_CLIENT_PATH		?= $(CURDIR)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_TEST_PATH			?= $(CURDIR)/optee_test
OPTEE_TEST_OUT_PATH		?= $(CURDIR)/optee_test/out
OPTEE_EXAMPLES_PATH		?= $(CURDIR)/optee_examples
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm-plat-imx/export-ta_arm32

CFG_TEE_CORE_LOG_LEVEL		?= 4

define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && $(MAKE) --no-print-directory kernelversion)
endef

################################################################################
# Targets
################################################################################
.PHONY: all

all: prepare uboot-imx linux-imx optee-imx

.PHONY: clean
clean: uboot-imx-clean linux-imx-clean optee-imx-clean prepare-cleane

.PHONY: prepare
prepare:
	mkdir -p $(OUT_PATH)

.PHONY: prepare-cleane
prepare-clean:
	rm -rf $(OUT_PATH)

################################################################################
# uboot-imx
################################################################################

UBOOT_DEFCONFIG_FILE=mx6qsabresd_optee_defconfig
UBOOT_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE) ARCH=$(ARCH)

.PHONY: uboot-imx
uboot-imx: uboot-imx-defconfig
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS)
	cp -f u-boot-dtb.imx $(OUT_PATH)

.PHONY: uboot-imx-defconfig
uboot-imx-defconfig:
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS) $(UBOOT_DEFCONFIG_FILE)

.PHONY: uboot-imx-clean
uboot-imx-clean:
	$(MAKE) -C $(UBOOT_PATH) $(UBOOT_FLAGS) clean

################################################################################
# Linux
################################################################################

LINUX_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE) \
					  ARCH=$(ARCH)
LINUX_MODULES_FLAGS ?= LOCALVERSION=$(LOCALVERSION) \
                      CROSS_COMPILE=$(CROSS_COMPILE) \
					  ARCH=$(ARCH) \
					  INSTALL_MOD_PATH=$(OUT_PATH)					  
LINUX_DEFCONFIG_FILES ?= imx_v7_defconfig

.PHONY: linux-imx
linux-imx: linux-common linux-module

.PHONY: linux-module
linux-module:
	$(MAKE) -C $(LINUX_PATH) $(LINUX_MODULES_FLAGS) modules_install

.PHONY: linux-common
linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) zImage modules dtbs
	cp -f $(LINUX_PATH)/arch/arm/boot/zImage $(OUT_PATH)
	cp -f $(LINUX_PATH)/arch/arm/boot/dts/imx6q-sabresd.dtb $(OUT_PATH)

.PHONY: linux-defconfig
linux-defconfig:
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) $(LINUX_DEFCONFIG_FILES)

.PHONY: linux-imx-clean
linux-imx-clean: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) clean

.PHONY: linux-defconfig-clean
linux-defconfig-clean:
	rm -f $(LINUX_PATH)/.config

################################################################################
# OP-TEE
################################################################################

.PHONY: optee-imx
optee-imx: optee-os optee-client optee-test optee-examples


.PHONY: optee-imx-clean
optee-imx-clean: optee-os-clean optee-client-clean optee-test-clean optee-examples-clean

OPTEE_OS_FLAGS ?= PLATFORM=$(PLATFORM) ARCH=$(ARCH) \
						CFG_BUILT_IN_ARGS=y CFG_PAGEABLE_ADDR=0 \
						CFG_NS_ENTRY_ADDR=0x12000000 \
						CFG_DT_ADDR=0x28000000 CFG_DT=y \
						CFG_PSCI_ARM32=y DEBUG=y \
						CFG_TEE_CORE_LOG_LEVEL=4 \
						CFG_BOOT_SYNC_CPU=n \
						CFG_BOOT_SECONDARY_REQUEST=y \
						CFG_IMXCRYPT=y \
						CROSS_COMPILE=$(CROSS_COMPILE)

OPTEE_OS_CLEAN_FLAGS ?= PLATFORM=$(PLATFORM) ARCH=$(ARCH)

.PHONY: optee-os
optee-os: optee-os-common
	$(UBOOT_PATH)/tools/mkimage -A arm -O linux -C none -a 0x13ffffe4 -e 0x14000000 -d $(OPTEE_OS_PATH)/out/arm-plat-imx/core/tee.bin uTee-6qsdb
	mv uTee-6qsdb $(OUT_PATH)

optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_FLAGS)

.PHONY: optee-os-clean
optee-os-clean: 
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_FLAGS) clean


################################################################################
# optee_client
################################################################################

OPTEE_CLIENT_FLAGS ?= ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

PHONY: optee-client
optee-client: 	
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_FLAGS)

.PHONY: optee-client-clean
optee-client-clean: 
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_FLAGS) clean

################################################################################
# xtest / optee_test
################################################################################

OPTEE_TEST_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	CROSS_COMPILE=${CROSS_COMPILE} \
	ARCH=$(ARCH) COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

.PHONY: optee-test
optee-test: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(OPTEE_TEST_FLAGS)

OPTEE_TEST_CLEAN_FLAGS ?= O=$(OPTEE_TEST_OUT_PATH) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \

.PHONY: optee-test-clean
optee-test-clean:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(OPTEE_TEST_CLEAN_FLAGS) clean

################################################################################
# sample applications / optee_examples
################################################################################
OPTEE_EXAMPLES_FLAGS ?= HOST_CROSS_COMPILE=$(CROSS_COMPILE)\
	TA_CROSS_COMPILE=$(CROSS_COMPILE) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT)

.PHONY: optee-examples
optee-examples: optee-os optee-client
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) $(OPTEE_EXAMPLES_FLAGS)

OPTEE_EXAMPLES_CLEAN_FLAGS ?= TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR)

.PHONY: optee-examples-clean
optee-examples-clean:
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) \
			$(OPTEE_EXAMPLES_CLEAN_FLAGS) clean
