# Keep Flutter core classes & platform channels
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Flutter Wrapper & Plugins
-keep class io.flutter.util.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.app.FlutterApplication { *; }

# Play Store Core / Deferred Components (Suppress unreferenced Play Store split install warnings)
-dontwarn com.google.android.play.core.**

# Keep native methods & channel handlers
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers class * extends java.lang.Enum {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Syncfusion & PDF
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# SQFlite & SQLite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Webview Flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# Archive & Compress
-dontwarn org.apache.commons.compress.**
