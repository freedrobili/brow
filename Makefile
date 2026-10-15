export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

APP := build/Brow.app
INSTALLED := $(HOME)/Applications/Brow.app
RELEASE := .build/release

.PHONY: test helper app run install screenshots

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
	cp Support/AppIcon.icns $(APP)/Contents/Resources/
	cp Resources/brow-media.pl $(APP)/Contents/Resources/
	cp $(RELEASE)/libBrowMediaRemote.dylib $(APP)/Contents/Resources/
	codesign --force --sign - $(APP)/Contents/Resources/libBrowMediaRemote.dylib
	codesign --force --sign - $(APP)

run: app
	pkill -x Brow && sleep 1 || true
	open $(APP)

# Copies Brow.app to ~/Applications (Spotlight, Launchpad) and starts it;
# on its first launch from there Brow turns on "open at login".
install: app
	pkill -x Brow && sleep 1 || true
	mkdir -p $(HOME)/Applications
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	open $(INSTALLED)

# Redraws the README pictures in docs/screenshots from the real views with demo data.
screenshots:
	swift build -c release
	$(RELEASE)/Brow --render-screenshots docs/screenshots
