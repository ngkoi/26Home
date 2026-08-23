TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = 26HomePrefs

26HomePrefs_FILES = Home26PrefsRootListController.m Home26ExceptionListController.m
26HomePrefs_FRAMEWORKS = UIKit
26HomePrefs_PRIVATE_FRAMEWORKS = Preferences
26HomePrefs_INSTALL_PATH = /Library/PreferenceBundles
26HomePrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
