TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 26Home

26Home_FILES = LGLiveBackdropView.m LGAdjustableBlurView.m HomeCustomizationMenu.m HomeCustomizationMenu18.m LGCustomIconGenerator2.m Hooks.x
26Home_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += 26HomePrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
