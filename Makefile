TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard Preferences Spotlight
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 26Home

26Home_FILES = LGLiveBackdropView.m LGAdjustableBlurView.m HomeCustomizationMenu.m HomeCustomizationMenu18.m LGCustomIconGenerator2.m LGButtonView.m Home26LiquidMenu.m \
               Hooks/HooksCommon.m \
               Hooks/EditingButtons.x \
               Hooks/IconView.x \
               Hooks/BadgesAndWidgets.x \
               Hooks/SpringBoardCore.x \
               Hooks/Preferences.x \
               Hooks/Spotlight.x \
               Hooks/Main.x
26Home_FRAMEWORKS = UIKit QuartzCore Metal CoreGraphics CoreImage
26Home_CFLAGS = -fobjc-arc -fvisibility=hidden -O3 -Iinclude
26Home_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += 26HomePrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
