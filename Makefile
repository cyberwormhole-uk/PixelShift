ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
THEOS_DEVICE_IP =

# Targeting: Dopamine (rootless) on iOS 15.0–18.7.1, A12/A13 (arm64e).
# Rootless jailbreaks (Dopamine, palera1n rootless) need THEOS_PACKAGE_SCHEME=rootless.
# Comment it out if you ever build for a rootful jailbreak instead.
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PixelShift
PixelShift_FILES = Tweak.xm
PixelShift_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
PixelShift_FRAMEWORKS = UIKit CoreFoundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
