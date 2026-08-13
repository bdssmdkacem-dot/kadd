#!/usr/bin/env python3
"""Patch the Flutter-generated AndroidManifest.xml for kadd.

The Android manifest is XML, and XML comments may NOT contain ``--``.
This script deliberately removes comments from injected XML fragments so
human-readable notes in the source fragments can never break manifest parsing.
"""
import re
import sys
from pathlib import Path

MANIFEST_PATH = Path("android/app/src/main/AndroidManifest.xml")
PERMISSIONS_PATH = Path("android_additions/manifest_permissions.xml")
APPLICATION_PATH = Path("android_additions/manifest_application.xml")
QUERIES_INTENTS_PATH = Path("android_additions/manifest_queries_intents.xml")


def strip_xml_comments(text: str) -> str:
    """Remove XML comments from an injected fragment.

    This is intentionally done before insertion. XML comments are documentation
    only and are not needed at runtime; removing them avoids SAX failures caused
    by accidental ``--`` sequences in translated/generated comments.
    """
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL).strip()


def assert_no_invalid_comment(text: str) -> None:
    """Fail early with a useful message if the final manifest has bad comments."""
    for match in re.finditer(r"<!--(.*?)-->", text, flags=re.DOTALL):
        if "--" in match.group(1):
            sys.exit("error: AndroidManifest.xml contains '--' inside an XML comment")


def main() -> None:
    if not MANIFEST_PATH.exists():
        sys.exit(
            f"error: {MANIFEST_PATH} not found — run `flutter create --platforms=android .` first"
        )

    manifest = MANIFEST_PATH.read_text(encoding="utf-8")
    permissions = strip_xml_comments(PERMISSIONS_PATH.read_text(encoding="utf-8"))
    application_block = strip_xml_comments(APPLICATION_PATH.read_text(encoding="utf-8"))
    queries_intents = strip_xml_comments(QUERIES_INTENTS_PATH.read_text(encoding="utf-8"))

    # Prevent duplicate patching if this script is run locally more than once.
    marker_start = "<!-- kadd: permissions injected by scripts/patch_manifest.py -->"
    if marker_start not in manifest:
        manifest_tag_end = manifest.find(">", manifest.find("<manifest"))
        if manifest_tag_end == -1:
            sys.exit("error: could not find <manifest ...> opening tag")
        insert_at = manifest_tag_end + 1
        injected = (
            "\n\n    " + marker_start + "\n    "
            + permissions.replace("\n", "\n    ")
            + "\n"
        )
        manifest = manifest[:insert_at] + injected + manifest[insert_at:]

    # Merge launcher visibility into Flutter's existing <queries> block.
    queries_close = "</queries>"
    queries_idx = manifest.find(queries_close)
    launcher_marker = "<!-- kadd: launcher-app visibility, injected by scripts/patch_manifest.py -->"
    if queries_idx != -1 and launcher_marker not in manifest:
        manifest = (
            manifest[:queries_idx]
            + "\n        " + launcher_marker + "\n        "
            + queries_intents.replace("\n", "\n        ")
            + "\n    "
            + manifest[queries_idx:]
        )
    elif queries_idx == -1:
        manifest_close = "</manifest>"
        close_idx = manifest.rfind(manifest_close)
        if close_idx == -1:
            sys.exit("error: could not find </manifest> closing tag")
        manifest = (
            manifest[:close_idx]
            + "    " + launcher_marker + "\n"
            + "    <queries>\n        "
            + queries_intents.replace("\n", "\n        ")
            + "\n    </queries>\n\n"
            + manifest[close_idx:]
        )

    # Insert service/activity/receivers before </application> once.
    components_marker = "<!-- kadd: components injected by scripts/patch_manifest.py -->"
    if components_marker not in manifest:
        close_tag = "</application>"
        idx = manifest.rfind(close_tag)
        if idx == -1:
            sys.exit("error: could not find </application> closing tag")
        manifest = (
            manifest[:idx]
            + "\n        " + components_marker + "\n        "
            + application_block.replace("\n", "\n        ")
            + "\n\n    "
            + manifest[idx:]
        )

    assert_no_invalid_comment(manifest)
    MANIFEST_PATH.write_text(manifest, encoding="utf-8")
    print(f"Patched {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
