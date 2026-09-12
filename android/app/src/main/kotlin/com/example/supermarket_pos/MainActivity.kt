package com.example.supermarket_pos

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle
import androidx.core.view.WindowCompat

// لازم FlutterFragmentActivity (مش FlutterActivity العادي) عشان مكتبة
// local_auth (الدخول بالبصمة) تشتغل - شرط أساسي من المكتبة نفسها
class MainActivity: FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

}
