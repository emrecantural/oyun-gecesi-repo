#!/usr/bin/env python3
"""flutter create çıktısını proje gereksinimlerine göre yamalar (CI'da çalışır).

- INTERNET izni, predictive back, appCategory=game, uygulama adı
- test/widget_test.dart şablonunu siler
- MainActivity: FLAG_SECURE ve FLAG_KEEP_SCREEN_ON için MethodChannel (platform/secure_screen.dart)
Yinelenen çalıştırmada güvenlidir (idempotent).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANIFEST = os.path.join(ROOT, "android/app/src/main/AndroidManifest.xml")
KOTLIN_DIR = os.path.join(ROOT, "android/app/src/main/kotlin/com/t14labs/oyungecesi")
TEMPLATE_TEST = os.path.join(ROOT, "test/widget_test.dart")

MAIN_ACTIVITY = '''package com.t14labs.oyungecesi

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oyungecesi/secure_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "keepOn" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "keepOff" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
'''


def patch_manifest() -> None:
    with open(MANIFEST, encoding="utf-8") as f:
        text = f.read()

    if "android.permission.INTERNET" not in text:
        text = text.replace(
            "<application",
            '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1,
        )
    if "enableOnBackInvokedCallback" not in text:
        text = text.replace(
            "<application",
            '<application\n        android:enableOnBackInvokedCallback="true"',
            1,
        )
    if "android:appCategory" not in text:
        text = text.replace(
            "<application",
            '<application\n        android:appCategory="game"',
            1,
        )
    text = re.sub(r'android:label="[^"]*"', 'android:label="Oyun Gecesi"', text, count=1)

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(text)


def patch_main_activity() -> None:
    os.makedirs(KOTLIN_DIR, exist_ok=True)
    # flutter create farklı bir dil/yol üretmişse eskisini kaldır.
    for name in ("MainActivity.kt", "MainActivity.java"):
        path = os.path.join(KOTLIN_DIR, name)
        if os.path.exists(path):
            os.remove(path)
    with open(os.path.join(KOTLIN_DIR, "MainActivity.kt"), "w", encoding="utf-8") as f:
        f.write(MAIN_ACTIVITY)


def main() -> int:
    if not os.path.exists(MANIFEST):
        print("AndroidManifest.xml yok; önce flutter create çalışmalı", file=sys.stderr)
        return 1
    patch_manifest()
    patch_main_activity()
    if os.path.exists(TEMPLATE_TEST):
        os.remove(TEMPLATE_TEST)
    print("android yaması uygulandı")
    return 0


if __name__ == "__main__":
    sys.exit(main())
