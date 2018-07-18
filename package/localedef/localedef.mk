################################################################################
#
# localedef
#
################################################################################

# Use the same VERSION and SITE as target glibc
LOCALEDEF_VERSION = glibc-2.27-57-g6c99e37f6fb640a50a3113b2dbee5d5389843c1e
LOCALEDEF_SITE = $(call github,bminor,glibc,$(GLIBC_VERSION))

HOST_LOCALEDEF_LICENSE = GPL-2.0+ (programs), LGPL-2.1+, BSD-3-Clause, MIT (library)
HOST_LOCALEDEF_LICENSE_FILES = COPYING COPYING.LIB LICENSES

# glibc is part of the toolchain so disable the toolchain dependency
HOST_LOCALEDEF_ADD_TOOLCHAIN_DEPENDENCY = NO

HOST_LOCALEDEF_SUBDIR = build

# Thumb build is broken, build in ARM mode
ifeq ($(BR2_ARM_INSTRUCTIONS_THUMB),y)
HOST_LOCALEDEF_EXTRA_CFLAGS += -marm
endif

# MIPS64 defaults to n32 so pass the correct -mabi if
# we are using a different ABI. OABI32 is also used
# in MIPS so we pass -mabi=32 in this case as well
# even though it's not strictly necessary.
ifeq ($(BR2_MIPS_NABI64),y)
HOST_LOCALEDEF_EXTRA_CFLAGS += -mabi=64
else ifeq ($(BR2_MIPS_OABI32),y)
HOST_LOCALEDEF_EXTRA_CFLAGS += -mabi=32
endif

ifeq ($(BR2_ENABLE_DEBUG),y)
HOST_LOCALEDEF_EXTRA_CFLAGS += -g
endif

# The stubs.h header is not installed by install-headers, but is
# needed for the gcc build. An empty stubs.h will work, as explained
# in http://gcc.gnu.org/ml/gcc/2002-01/msg00900.html. The same trick
# is used by Crosstool-NG.
ifeq ($(BR2_TOOLCHAIN_BUILDROOT_HOST_LOCALEDEF),y)
define HOST_LOCALEDEF_ADD_MISSING_STUB_H
	mkdir -p $(STAGING_DIR)/usr/include/gnu
	touch $(STAGING_DIR)/usr/include/gnu/stubs.h
endef
endif

# Even though we use the autotools-package infrastructure, we have to
# override the default configure commands for several reasons:
#
#  1. We have to build out-of-tree, but we can't use the same
#     'symbolic link to configure' used with the gcc packages.
#
#  2. We have to execute the configure script with bash and not sh.
#
# Note that as mentionned in
# http://patches.openembedded.org/patch/38849/, glibc must be
# built with -O2, so we pass our own CFLAGS and CXXFLAGS below.
define HOST_LOCALEDEF_CONFIGURE_CMDS
	mkdir -p $(@D)/build
	# Do the configuration
	(cd $(@D)/build; \
		$(HOST_CONFIGURE_OPTS) \
		CFLAGS="-O2 $(HOST_LOCALEDEF_EXTRA_CFLAGS)" CPPFLAGS="" \
		CXXFLAGS="-O2 $(HOST_LOCALEDEF_EXTRA_CFLAGS)" \
		$(SHELL) $(@D)/configure \
		ac_cv_path_BASH_SHELL=/bin/bash \
		libc_cv_forced_unwind=yes \
		libc_cv_ssp=no \
		--target=$(GNU_HOST_NAME) \
		--host=$(GNU_HOST_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		$(if $(BR2_SOFT_FLOAT),--without-fp,--with-fp) \
		$(if $(BR2_x86_64),--enable-lock-elision) \
		--with-pkgversion="Buildroot" \
		--without-cvs \
		--disable-profile \
		--without-gd \
		--enable-obsolete-rpc)
	$(HOST_LOCALEDEF_ADD_MISSING_STUB_H)
endef

$(eval $(autotools-package))
# The makefile does not implement an install target for localedef
define HOST_LOCALEDEF_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/build/locale/localedef $(HOST_DIR)/bin/localedef
endef

$(eval $(host-autotools-package))
