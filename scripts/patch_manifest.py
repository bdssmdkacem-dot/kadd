#!/usr/bin/env python3
"""
Injects android_additions/manifest_permissions.xml right after the opening
<manifest ...> tag, and android_additions/manifest_application.xml right
before the closing </application> tag, of the AndroidManifest.xml that
`flutter create` generates.

Run from the repo root, after `flutter create --platforms=android .` has
produced android/app/src/main/AndroidManifest.xml.
"""
import sys
from pathlib import Path

MANIFEST_PATH = Path("android/app/src/main/AndroidManifest.xml")
PERMISSIONS_PATH = Path("android_additions/manifest_permissions.xml")
APPLICATION_PATH = Path("android_additions/manifest_application.xml")


def main():
    if not MANIFEST_PATH.exists():
        sys.exit(f"error: {MANIFEST_PATH} not found — run `flutter create --platforms=android .` first")

    manifest = MANIFEST_PATH.read_text(encoding="utf-8")
    permissions = PERMISSIONS_PATH.read_text(encoding="utf-8").strip()
    application_block = APPLICATION_PATH.read_text(encoding="utf-8").strip()

    # Insert permissions right after the opening <manifest ...> tag's closing '>'.
    manifest_tag_end = manifest.find(">", manifest.find("<manifest"))
    if manifest_tag_end == -1:
        sys.exit("error: could not find <manifest ...> opening tag")
    insert_at = manifest_tag_end + 1
    manifest = (
        manifest[:insert_at]
        + "\n\n    <!-- kadd: permissions injected by scripts/patch_manifest.py -->\n    "
        + permissions.replace("\n", "\n    ")
        + "\n"
        + manifest[insert_at:]
    )

    # Insert the service/activity/receivers right before </application>.
    close_tag = "</application>"
    idx = manifest.rfind(close_tag)
    if idx == -1:
        sys.exit("error: could not find </application> closing tag")
    manifest = (
        manifest[:idx]
        + "\n        <!-- kadd: components injected by scripts/patch_manifest.py -->\n        "
        + application_block.replace("\n", "\n        ")
        + "\n\n    "
        + manifest[idx:]
    )

    MANIFEST_PATH.write_text(manifest, encoding="utf-8")
    print(f"Patched {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
