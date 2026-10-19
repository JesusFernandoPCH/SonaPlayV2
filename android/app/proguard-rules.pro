# Flutter ProGuard Rules for SonaPlay

# Keep essential Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# Audio Service / Just Audio
-keep class com.ryanheise.audio_service.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# Hive (NoSQL Database)
-keep class com.google.protobuf.** { *; }
-keep class io.hive.** { *; }
-keep class * extends io.hive.TypeAdapter
-keep class * extends io.hive.HiveObject

# Persistent local data models (keep from obfuscation for Hive)
-keep class com.example.sonaplay.features.library.data.models.** { *; }

# Riverpod
-keep class com.example.sonaplay.** { *; }

# Google Play Core (Fix for missing classes during R8 minification)
-dontwarn com.google.android.play.core.**
