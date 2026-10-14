export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

APP := build/Brow.app
RELEASE := .build/release

.PHONY: test helper app run

test:
	swift test

helper:
	swift build -c release --product BrowMediaRemote

app:
	swift build -c release
	swift build -c release --product BrowMediaRemote
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(RELEASE)/Brow $(APP)/Contents/MacOS/Brow
	cp Support/Info.plist $(APP)/Contents/Info.plist
	cp Resources/brow-media.pl $(APP)/Contents/Resources/
	cp $(RELEASE)/libBrowMediaRemote.dylib $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)/Contents/Resources/libBrowMediaRemote.dylib
	codesign --force --sign - $(APP)

run: app
	pkill -x Brow || true
	open $(APP)
