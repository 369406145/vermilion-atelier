package studio.vermilion.atelier

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val ink = Color.parseColor("#12100E")
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(ink),
            navigationBarStyle = SystemBarStyle.dark(ink),
        )
        setContent { AtelierApp() }
    }
}
