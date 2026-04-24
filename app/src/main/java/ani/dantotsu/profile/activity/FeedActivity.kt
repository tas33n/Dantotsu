package ani.dantotsu.profile.activity

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import ani.dantotsu.R
import ani.dantotsu.initActivity
import ani.dantotsu.themes.ThemeManager

class FeedActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ThemeManager(this).applyTheme()
        setContentView(R.layout.activity_container)
        initActivity(this)

        if (savedInstanceState == null) {
            val userId = intent.getIntExtra("userId", 0).takeIf { it != 0 }
            supportFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, ActivityFragment.newInstance(userId))
                .commit()
        }
    }
}
