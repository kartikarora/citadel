import subprocess
import os

# Inspect Terminal.app or Xcode icon to see exact proportions and rounded squircle shape
icon_path = "/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns"
if os.path.exists(icon_path):
    subprocess.run(["iconutil", "-c", "iconset", icon_path, "-o", "/tmp/terminal.iconset"])
    print("Extracted Terminal.icns to /tmp/terminal.iconset")
    subprocess.run(["sips", "-g", "all", "/tmp/terminal.iconset/icon_512x512@2x.png"])
