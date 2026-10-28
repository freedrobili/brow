export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

# Spotlight skips *.noindex folders, so this development copy never shows up there.
APP := .build/app.noindex/Brow.app
INSTALLED := $(HOME)/Applications/Brow.app
RELEASE := .build/release
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)
ZIP := .build/dist/Brow-$(VERSION).zip
SPARKLE := .build/artifacts/sparkle/Sparkle
APPCAST_DIR := .build/appcast
REPO := freedrobili/brow

.PHONY: test helper app run install screenshots release appcast publish

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
	mkdir -p $(APP)/Contents/Frameworks
	ditto $(SPARKLE)/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework $(APP)/Contents/Frameworks/Sparkle.framework
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
	scripts/check-other-copies.sh $(INSTALLED)
	open $(INSTALLED)

# Redraws the README pictures in docs/screenshots from the real views with demo data.
screenshots:
	swift build -c release
	$(RELEASE)/Brow --render-screenshots docs/screenshots

# Packs the app for GitHub Releases; ditto keeps the code signature intact.
release: test app
	rm -f $(ZIP)
	mkdir -p $(dir $(ZIP))
	ditto -c -k --sequesterRsrc --keepParent $(APP) $(ZIP)
	@echo "Ready: $(ZIP)"

# Signs the release zip with the Sparkle key from the Keychain (account
# com.freedrobili.Brow) and writes the update feed. NOTES is the release notes
# file (Markdown); it is embedded so the update window shows what changed.
appcast: release
	@test -n "$(NOTES)" || (echo "Usage: make appcast NOTES=path/to/release-notes.md"; exit 1)
	rm -rf $(APPCAST_DIR) && mkdir -p $(APPCAST_DIR)
	cp $(ZIP) $(APPCAST_DIR)/
	cp $(NOTES) $(APPCAST_DIR)/Brow-$(VERSION).md
	$(SPARKLE)/bin/generate_appcast --account com.freedrobili.Brow --embed-release-notes \
		--download-url-prefix https://github.com/$(REPO)/releases/download/v$(VERSION)/ \
		--link https://github.com/$(REPO)/releases/tag/v$(VERSION) $(APPCAST_DIR)
	@echo "Feed: $(APPCAST_DIR)/appcast.xml"

# Publishes the GitHub release with the zip and the feed; installed copies of
# Brow pick it up from releases/latest/download/appcast.xml.
publish: appcast
	gh release create v$(VERSION) $(ZIP) $(APPCAST_DIR)/appcast.xml --repo $(REPO) --target main \
		--title "Brow $(VERSION)" --notes-file $(NOTES)
