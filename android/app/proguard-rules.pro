# Flutter / embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google ML Kit — text recognition & document scanner
# ML Kit loads models via reflection; keep its classes and the optional
# language-specific text recognizers referenced by Play services.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Play Core / Play Billing (in_app_purchase)
-keep class com.android.vending.billing.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep annotations & generic signatures used by reflection-heavy libs
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
