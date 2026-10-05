TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = 26HomePrefs

26HomePrefs_FILES = Home26PrefsRootListController.m Home26ExceptionListController.m Home26IconPacksListController.m Home26WallpaperHelper.m Home26WallpaperCropViewController.m Home26IconPickerViewController.m Home26PackDetailViewController.m Home26IconGenConfigController.m Home26AppIconGenListController.m Home26AppIconGenDetailController.m ../LGLiveBackdropView.m ../LGAdjustableBlurView.m ../LGCustomIconGenerator2.m
26HomePrefs_FRAMEWORKS = UIKit CoreImage CoreGraphics QuartzCore
26HomePrefs_PRIVATE_FRAMEWORKS = Preferences
26HomePrefs_INSTALL_PATH = /Library/PreferenceBundles
26HomePrefs_CFLAGS = -fobjc-arc -I../
26HomePrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
