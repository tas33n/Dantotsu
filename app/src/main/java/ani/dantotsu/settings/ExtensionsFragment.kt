package ani.dantotsu.settings

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.AutoCompleteTextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import ani.dantotsu.R
import ani.dantotsu.databinding.FragmentExtensionsHostBinding
import ani.dantotsu.media.MediaType
import ani.dantotsu.others.LanguageMapper
import ani.dantotsu.parsers.ParserTestActivity
import ani.dantotsu.settings.saving.PrefManager
import ani.dantotsu.settings.saving.PrefName
import ani.dantotsu.util.customAlertDialog
import com.google.android.material.tabs.TabLayout
import com.google.android.material.tabs.TabLayoutMediator
import java.util.Locale

class ExtensionsFragment : Fragment() {
    private var _binding: FragmentExtensionsHostBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentExtensionsHostBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.searchExtensionsButton.setOnClickListener {
            if (binding.searchView.visibility == View.GONE) {
                binding.headerLayout.visibility = View.GONE
                binding.searchView.visibility = View.VISIBLE
                binding.searchViewText.requestFocus()
            } else {
                binding.headerLayout.visibility = View.VISIBLE
                binding.searchView.visibility = View.GONE
                binding.searchViewText.setText("")
                binding.searchViewText.clearFocus()
            }
        }

        binding.searchView.setStartIconOnClickListener {
            binding.headerLayout.visibility = View.VISIBLE
            binding.searchView.visibility = View.GONE
            binding.searchViewText.setText("")
            binding.searchViewText.clearFocus()
        }

        binding.searchViewText.setOnFocusChangeListener { _, hasFocus ->
            if (!hasFocus && binding.searchViewText.text.isNullOrEmpty()) {
                binding.headerLayout.visibility = View.VISIBLE
                binding.searchView.visibility = View.GONE
            }
        }

        binding.testButton.setOnClickListener {
            ContextCompat.startActivity(
                requireContext(),
                Intent(requireContext(), ParserTestActivity::class.java),
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

        val tabLayout = binding.tabLayout
        val viewPager = binding.viewPager
        val searchViewText: AutoCompleteTextView = binding.searchViewText

        tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                searchViewText.setText("")
                searchViewText.clearFocus()
                tabLayout.clearFocus()
                if (tab.text?.contains("Installed") == true) binding.languageselect.visibility = View.GONE
                else binding.languageselect.visibility = View.VISIBLE
                generateRepositoryButton(MediaType.ANIME)
            }
            override fun onTabUnselected(tab: TabLayout.Tab) {}
            override fun onTabReselected(tab: TabLayout.Tab) {}
        })

        TabLayoutMediator(tabLayout, viewPager) { tab, position ->
            tab.text = when (position) {
                0 -> "Installed"
                else -> "Available"
            }
        }.attach()

        searchViewText.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) {}
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val currentFragment = childFragmentManager.findFragmentByTag("f${viewPager.currentItem}")
                if (currentFragment is SearchQueryHandler) {
                    currentFragment.updateContentBasedOnQuery(s?.toString()?.trim())
                }
            }
        })

        binding.languageselect.setOnClickListener {
            val languageOptions = LanguageMapper.Companion.Language.entries.map { entry ->
                entry.name.lowercase().replace("_", " ")
                    .replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }
            }.toTypedArray()
            val listOrder: String = PrefManager.getVal(PrefName.LangSort)
            val index = LanguageMapper.Companion.Language.entries.toTypedArray()
                .indexOfFirst { it.code == listOrder }
            requireContext().customAlertDialog().apply {
                setTitle("Language")
                singleChoiceItems(languageOptions, index) { selected ->
                    PrefManager.setVal(PrefName.LangSort, LanguageMapper.Companion.Language.entries[selected].code)
                    val currentFragment = childFragmentManager.findFragmentByTag("f${viewPager.currentItem}")
                    if (currentFragment is SearchQueryHandler) {
                        currentFragment.notifyDataChanged()
                    }
                }
                show()
            }
        }
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
            ).show(childFragmentManager, "add_repo")
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}