#!/bin/sh
# Pins an app to the Dock once (no duplicate if it is already there) and restarts the Dock.
# Usage: scripts/add-to-dock.sh /path/to/App.app
set -e
app="$1"
if defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "file://$app/"; then
    echo "Already in the Dock: $app"
    exit 0
fi
defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://$app/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
killall Dock
echo "Added to the Dock: $app"
