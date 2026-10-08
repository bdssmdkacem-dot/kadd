#!/usr/bin/env python3
"""Build the Android platform from canonical Kadd additions.

Flutter owns the generated Android project. Kadd owns only the native additions
under android_additions/. This script patches the generated project deterministically
so local builds and CI use the same Android configuration.
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
MANIFEST_PATH = ANDROID / "app/src/main/AndroidManifest.xml"
APP_GRADLE_PATH = next((p for p in (ANDROID / "app/build.gradle", ANDROID / "app/build.gradle.kts") if p.exists()), ANDROID / "app/build.gradle")
STYLES_PATH = ANDROID / "app/src/main/res/values/styles.xml"

PERMISSIONS_PATH = ROOT / "android_additions/manifest_permissions.xml"
APPLICATION_PATH = ROOT / "android_additions/manifest_application.xml"
QUERIES_INTENTS_PATH = ROOT / "android_additions/manifest_queries_intents.xml"
LOCK_THEME_PATH = ROOT / "android_additions/res/values/lock_theme.xml"


def strip_xml_comments(text: str) -> str:
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL).strip()


def fail(message: str) -> None:
    sys.exit(f"error: {message}")


def patch_manifest() -> None:
    if os.environ.get("KADD_REQUIRE_PRODUCTION_SIGNING") == "1":
        app_id = os.environ.get("KADD_ADMOB_APP_ID", "").strip()
        if not app_id or app_id == "ca-app-pub-3940256099942544~3347511713":
            fail("production signing requested but a real KADD_ADMOB_APP_ID is missing")

    if not MANIFEST_PATH.exists():
        fail(f"{MANIFEST_PATH} not found — run flutter create --platforms=android --org com.comptaflow . first")

    manifest = MANIFEST_PATH.read_text(encoding="utf-8")
    permissions = strip_xml_comments(PERMISSIONS_PATH.read_text(encoding="utf-8"))
    application_block = strip_xml_comments(APPLICATION_PATH.read_text(encoding="utf-8"))
    queries_intents = strip_xml_comments(QUERIES_INTENTS_PATH.read_text(encoding="utf-8"))

    marker_start = "<!-- kadd: permissions injected by scripts/patch_manifest.py -->"
    if marker_start not in manifest:
        manifest_tag_end = manifest.find(">", manifest.find("<manifest"))
        if manifest_tag_end == -1:
            fail("could not find <manifest ...> opening tag")
        injected = "\n\n    " + marker_start + "\n    " + permissions.replace("\n", "\n    ") + "\n"
        manifest = manifest[:manifest_tag_end + 1] + injected + manifest[manifest_tag_end + 1:]

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
            fail("could not find </manifest> closing tag")
        manifest = (
            manifest[:close_idx]
            + "    " + launcher_marker + "\n"
            + "    <queries>\n        "
            + queries_intents.replace("\n", "\n        ")
            + "\n    </queries>\n\n"
            + manifest[close_idx:]
        )

    components_marker = "<!-- kadd: components injected by scripts/patch_manifest.py -->"
    if components_marker not in manifest:
        close_tag = "</application>"
        idx = manifest.rfind(close_tag)
        if idx == -1:
            fail("could not find </application> closing tag")
        manifest = (
            manifest[:idx]
            + "\n        " + components_marker + "\n        "
            + application_block.replace("\n", "\n        ")
            + "\n\n    "
            + manifest[idx:]
        )

    manifest = manifest.replace(
        'xmlns:android="http://schemas.android.com/apk/res/android"',
        'xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"',
        1,
    ) if 'xmlns:tools=' not in manifest else manifest

    for match in re.finditer(r"<!--(.*?)-->", manifest, flags=re.DOTALL):
        if "--" in match.group(1):
            fail("AndroidManifest.xml contains '--' inside an XML comment")

    MANIFEST_PATH.write_text(manifest, encoding="utf-8")


def patch_gradle() -> None:
    if not APP_GRADLE_PATH.exists():
        fail(f"{APP_GRADLE_PATH} not found")

    gradle = APP_GRADLE_PATH.read_text(encoding="utf-8")
    is_kotlin_dsl = APP_GRADLE_PATH.name.endswith(".kts")
    marker = "// kadd: generated Android configuration"

    if marker not in gradle:
        # Kadd is an Android-first Play app. Keep compile/target SDK at API 36.
        gradle = re.sub(
            r"(?m)^\s*compileSdk\s*=.*$",
            "    compileSdk = 36" if is_kotlin_dsl else "    compileSdk 36",
            gradle,
            count=1,
        )
        gradle = re.sub(
            r"(?m)^\s*targetSdk\s*=.*$",
            "        targetSdk = 36" if is_kotlin_dsl else "        targetSdk 36",
            gradle,
            count=1,
        )

        needle = "defaultConfig {"
        idx = gradle.find(needle)
        if idx == -1:
            fail(f"could not find defaultConfig block in generated {APP_GRADLE_PATH.name}")

        if is_kotlin_dsl:
            insertion = (
                f"{needle}\n"
                f"        {marker}\n"
                '        manifestPlaceholders["KADD_ADMOB_APP_ID"] = '
                '(System.getenv("KADD_ADMOB_APP_ID") ?: '
                '"ca-app-pub-3940256099942544~3347511713")\n'
            )
        else:
            insertion = (
                f"{needle}\\n"
                f"        {marker}\\n"
                "        manifestPlaceholders = ["
                " KADD_ADMOB_APP_ID: System.getenv('KADD_ADMOB_APP_ID') ?: "
                "'ca-app-pub-3940256099942544~3347511713'"
                " ]\\n"
            )
        gradle = gradle[:idx] + insertion + gradle[idx + len(needle):]

    if os.environ.get("KADD_REQUIRE_PRODUCTION_SIGNING") == "1":
        keystore = os.environ.get("KADD_RELEASE_KEYSTORE", "")
        if not keystore or not Path(keystore).is_file():
            fail("production signing requested but KADD_RELEASE_KEYSTORE does not point to a keystore")

        signing_marker = "// kadd: production signing"
        if signing_marker not in gradle:
            if is_kotlin_dsl:
                gradle += """
                
// kadd: production signing
android {
    signingConfigs {
        create("kaddProduction") {
            storeFile = file(System.getenv("KADD_RELEASE_KEYSTORE"))
            storePassword = System.getenv("KADD_RELEASE_STORE_PASSWORD")
            keyAlias = System.getenv("KADD_RELEASE_KEY_ALIAS")
            keyPassword = System.getenv("KADD_RELEASE_KEY_PASSWORD")
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("kaddProduction")
        }
    }
}
"""
            else:
                gradle += """
                
// kadd: production signing
android.signingConfigs.create("kaddProduction") {
    storeFile = file(System.getenv("KADD_RELEASE_KEYSTORE"))
    storePassword = System.getenv("KADD_RELEASE_STORE_PASSWORD")
    keyAlias = System.getenv("KADD_RELEASE_KEY_ALIAS")
    keyPassword = System.getenv("KADD_RELEASE_KEY_PASSWORD")
}
android.buildTypes.release.signingConfig = android.signingConfigs.kaddProduction
"""

    APP_GRADLE_PATH.write_text(gradle, encoding="utf-8")

def patch_styles() -> None:
    if not STYLES_PATH.exists():
        fail(f"{STYLES_PATH} not found")
    if not LOCK_THEME_PATH.exists():
        fail(f"{LOCK_THEME_PATH} not found")
    styles = STYLES_PATH.read_text(encoding="utf-8")
    lock_theme = strip_xml_comments(LOCK_THEME_PATH.read_text(encoding="utf-8"))
    marker = "kadd: LockTheme"
    if marker not in styles:
        idx = styles.rfind("</resources>")
        if idx == -1:
            fail("could not find </resources> in generated styles.xml")
        styles = styles[:idx] + "\n    <!-- " + marker + " -->\n    " + lock_theme + "\n" + styles[idx:]
    STYLES_PATH.write_text(styles, encoding="utf-8")


def main() -> None:
    patch_manifest()
    patch_gradle()
    patch_styles()
    print("Patched generated Android project from android_additions/")


if __name__ == "__main__":
    main()
