package ani.dantotsu.settings

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.updateLayoutParams
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import ani.dantotsu.R
import ani.dantotsu.databinding.ActivityExtensionsBinding
import ani.dantotsu.initActivity
import ani.dantotsu.media.MediaType
import ani.dantotsu.parsers.ParserTestActivity
import ani.dantotsu.settings.saving.PrefManager
import ani.dantotsu.settings.saving.PrefName
import ani.dantotsu.themes.ThemeManager
import com.google.android.material.tabs.TabLayout
import com.google.android.material.tabs.TabLayoutMediator

import androidx.activity.OnBackPressedCallback

class ExtensionsActivity : AppCompatActivity(), ExtensionUIToggle {
    lateinit var binding: ActivityExtensionsBinding

    private val backPressedCallback = object : OnBackPressedCallback(false) {
        override fun handleOnBackPressed() {
            if (!supportFragmentManager.popBackStackImmediate()) {
                isEnabled = false
                onBackPressedDispatcher.onBackPressed()
            }
        }
    }

    override fun toggleUI(show: Boolean, name: String) {
        binding.viewPager.visibility = if (show) View.VISIBLE else View.GONE
        binding.tabLayout.visibility = if (show) View.VISIBLE else View.GONE
        binding.searchView.visibility = if (show) View.VISIBLE else View.GONE
        binding.languageselect.visibility = if (show) View.VISIBLE else View.GONE
        binding.extensions.text = if (show) getString(R.string.extensions) else name
        binding.fragmentExtensionsContainer.visibility = if (show) View.GONE else View.VISIBLE
        backPressedCallback.isEnabled = !show
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        onBackPressedDispatcher.addCallback(this, backPressedCallback)

        ThemeManager(this).applyTheme()
        binding = ActivityExtensionsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        initActivity(this)

        binding.searchExtensionsButton.setOnClickListener {
            if (binding.searchView.visibility == View.GONE) {
                binding.headerLayout.visibility = View.GONE
                binding.searchView.visibility = View.VISIBLE
                binding.searchViewText.requestFocus()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                imm.showSoftInput(binding.searchViewText, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
            } else {
                binding.headerLayout.visibility = View.VISIBLE
                binding.searchView.visibility = View.GONE
                binding.searchViewText.setText("")
                binding.searchViewText.clearFocus()
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                imm.hideSoftInputFromWindow(binding.searchViewText.windowToken, 0)
            }
        }

        binding.searchView.setStartIconOnClickListener {
            binding.headerLayout.visibility = View.VISIBLE
            binding.searchView.visibility = View.GONE
            binding.searchViewText.setText("")
            binding.searchViewText.clearFocus()
            val currentFragment = supportFragmentManager.findFragmentByTag("f${binding.viewPager.currentItem}")
            if (currentFragment is SearchQueryHandler) {
                currentFragment.updateContentBasedOnQuery("")
            }
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            imm.hideSoftInputFromWindow(binding.searchViewText.windowToken, 0)
        }

        binding.searchViewText.setOnFocusChangeListener { _, hasFocus ->
            if (!hasFocus && binding.searchViewText.text.isNullOrEmpty()) {
                binding.headerLayout.visibility = View.VISIBLE
                binding.searchView.visibility = View.GONE
            }
        }

        binding.testButton.setOnClickListener {
            ContextCompat.startActivity(
                this,
                Intent(this, ParserTestActivity::class.java),
                null
            )
        }

        binding.viewPager.offscreenPageLimit = 1
        binding.viewPager.adapter = object : FragmentStateAdapter(this) {
            override fun getItemCount(): Int = 2
            override fun createFragment(position: Int): Fragment {
                return when (position) {
                    0 -> InstalledAnimeExtensionsFragment()
                    else -> AnimeExtensionsFragment()
                }
            }
        }

        binding.tabLayout.addOnTabSelectedListener(
            object : TabLayout.OnTabSelectedListener {
                override fun onTabSelected(tab: TabLayout.Tab) {
                    binding.searchViewText.setText("")
                    binding.searchViewText.clearFocus()
                    binding.tabLayout.clearFocus()
                    binding.headerLayout.visibility = View.VISIBLE
                    binding.searchView.visibility = View.GONE
                    if (tab.text?.contains("Installed") == true) binding.languageselect.visibility = View.GONE
                    else binding.languageselect.visibility = View.VISIBLE
                    binding.viewPager.updateLayoutParams<ViewGroup.LayoutParams> {
                        height = ViewGroup.LayoutParams.MATCH_PARENT
                    }
                    generateRepositoryButton(MediaType.ANIME)
                }
                override fun onTabUnselected(tab: TabLayout.Tab) {}
                override fun onTabReselected(tab: TabLayout.Tab) {}
            }
        )

        TabLayoutMediator(binding.tabLayout, binding.viewPager) { tab, position ->
            tab.text = when (position) {
                0 -> "Installed"
                else -> "Available"
            }
        }.attach()

        binding.searchViewText.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) {}
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val currentFragment = supportFragmentManager.findFragmentByTag("f${binding.viewPager.currentItem}")
                if (currentFragment is SearchQueryHandler) {
                    currentFragment.updateContentBasedOnQuery(s?.toString()?.trim())
                }
            }
        })
        generateRepositoryButton(MediaType.ANIME)
    }

    private fun generateRepositoryButton(type: MediaType) {
        binding.openSettingsButton.setOnClickListener {
            val repos: Set<String> = PrefManager.getVal(PrefName.AnimeExtensionRepos)
            AddRepositoryBottomSheet.newInstance(
                type,
                repos.toList(),
                AddRepositoryBottomSheet::addRepo,
                AddRepositoryBottomSheet::removeRepo
            ).show(supportFragmentManager, "add_repo")
        }
    }
}
