# Google ML Kit Rules to prevent R8/minify missing classes errors
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
