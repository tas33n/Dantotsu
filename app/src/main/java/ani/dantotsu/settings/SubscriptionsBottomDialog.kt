package ani.dantotsu.settings

import android.graphics.drawable.Drawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.widget.PopupMenu
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import ani.dantotsu.R
import ani.dantotsu.databinding.BottomSheetSubscriptionsBinding
import ani.dantotsu.media.SubscriptionAdapter
import ani.dantotsu.media.SubscriptionHelper
import ani.dantotsu.snackString
import com.google.android.material.bottomsheet.BottomSheetDialogFragment

class SubscriptionsBottomDialog : BottomSheetDialogFragment() {
    private var _binding: BottomSheetSubscriptionsBinding? = null
    private val binding get() = _binding!!

    private var subscriptions: Map<Int, SubscriptionHelper.Companion.SubscribeMedia> = emptyMap()
    private var filteredSubscriptions: List<SubscriptionHelper.Companion.SubscribeMedia> = emptyList()
    private var currentFilter: Filter = Filter.ALL

    enum class Filter {
        ALL, ANIME, MANGA
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = BottomSheetSubscriptionsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.filterButton.setOnClickListener { showFilterMenu(it) }
        applyFilter(currentFilter)
    }

    private fun showFilterMenu(view: View) {
        val popup = PopupMenu(requireContext(), view)
        popup.menuInflater.inflate(R.menu.subscriptions_filter_menu, popup.menu)
        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                R.id.filter_all -> applyFilter(Filter.ALL)
                R.id.filter_anime -> applyFilter(Filter.ANIME)
                R.id.filter_manga -> applyFilter(Filter.MANGA)
            }
            true
        }
        popup.show()
    }

    private fun applyFilter(filter: Filter) {
        currentFilter = filter
        filteredSubscriptions = when (filter) {
            Filter.ALL -> subscriptions.values.toList()
            Filter.ANIME -> subscriptions.values.filter { it.type == "ANIME" }
            Filter.MANGA -> subscriptions.values.filter { it.type == "MANGA" }
        }

        binding.subscriptionsRecyclerView.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = SubscriptionAdapter(filteredSubscriptions)
        }

        binding.noSubscriptionsText.isVisible = filteredSubscriptions.isEmpty()
        
        val filterIcon: Drawable? = when (filter) {
            Filter.ALL -> ContextCompat.getDrawable(requireContext(), R.drawable.ic_round_filter_list_24)
            Filter.ANIME -> ContextCompat.getDrawable(requireContext(), R.drawable.ic_round_movie_filter_24)
            Filter.MANGA -> ContextCompat.getDrawable(requireContext(), R.drawable.ic_round_import_contacts_24)
        }
        binding.filterButton.setImageDrawable(filterIcon)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    companion object {
        fun newInstance(subscriptions: Map<Int, SubscriptionHelper.Companion.SubscribeMedia>): SubscriptionsBottomDialog {
            val dialog = SubscriptionsBottomDialog()
            dialog.subscriptions = subscriptions
            return dialog
        }
    }
}
