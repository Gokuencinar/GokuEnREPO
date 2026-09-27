ARCHS = arm64
TARGET = iphone:clang:16.5:16.0
export ARCHS
export TARGET

# Reuse the Dopamine source tree, but compile it without the rootless package
# scheme and with the small runtime differences needed by classic rootful.
export BANDLOCK_VARIANT_CFLAGS = -DBL_VARIANT_ROOTFUL=1

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += \
	../BandLock-1.0-Dopamine/app \
	../BandLock-1.0-Dopamine/daemon \
	../BandLock-1.0-Dopamine/launcher \
	../BandLock-1.0-Dopamine/fieldbridge \
	../BandLock-1.0-Dopamine/ccmodule
include $(THEOS_MAKE_PATH)/aggregate.mk
