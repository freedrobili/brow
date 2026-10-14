export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

.PHONY: test

test:
	swift test

.PHONY: helper

helper:
	swift build -c release --product BrowMediaRemote
