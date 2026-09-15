# Bỏ qua cảnh báo thiếu class
-dontwarn com.google.mlkit.**
-dontwarn io.flutter.**

# Giữ nguyên toàn bộ cấu trúc của Google ML Kit (Không được cắt xén)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Giữ nguyên cấu trúc lõi của Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.app.** { *; }