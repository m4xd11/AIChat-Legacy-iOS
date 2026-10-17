export ARCHS = armv7
export TARGET = iphone:clang:latest:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AIChat
AIChat_FILES = main.m AppDelegate.m ChatViewController.m
AIChat_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
AIChat_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
