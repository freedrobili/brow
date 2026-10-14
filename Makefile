export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

.PHONY: test

test:
	swift test
