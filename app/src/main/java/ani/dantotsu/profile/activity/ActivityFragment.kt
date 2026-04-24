package ani.dantotsu.profile.activity

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.view.isGone
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import ani.dantotsu.connections.anilist.Anilist
import ani.dantotsu.databinding.BottomSheetRecyclerBinding
import ani.dantotsu.media.MediaDetailsActivity
import ani.dantotsu.profile.ProfileActivity
import com.xwray.groupie.GroupieAdapter
import kotlinx.coroutines.launch

class ActivityFragment : Fragment() {
    private var _binding: BottomSheetRecyclerBinding? = null
    private val binding get() = _binding!!
    private val adapter = GroupieAdapter()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = BottomSheetRecyclerBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.repliesRecyclerView.layoutManager = LinearLayoutManager(requireContext())
        binding.repliesRecyclerView.adapter = adapter
        binding.replyButton.isGone = true
        binding.title.text = "Activity"

        val userId = arguments?.getInt("userId")?.takeIf { it != 0 }
        loadActivities(userId)
    }

    private fun loadActivities(userId: Int? = null) {
        binding.repliesRefresh.isGone = false
        lifecycleScope.launch {
            val res = Anilist.query.getFeed(userId = userId, global = userId == null && Anilist.token == null)
            res?.data?.page?.activities?.forEach { activity ->
                adapter.add(ActivityItem(activity, adapter) { id, type ->
                    when (type) {
                        "USER" -> {
                            startActivity(
                                Intent(requireContext(), ProfileActivity::class.java)
                                    .putExtra("userId", id)
                            )
                        }
                        "MEDIA" -> {
                            startActivity(
                                Intent(requireContext(), MediaDetailsActivity::class.java)
                                    .putExtra("mediaId", id)
                            )
                        }
                    }
                })
            }
            binding.repliesRefresh.isGone = true
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    companion object {
        fun newInstance(userId: Int? = null): ActivityFragment {
            return ActivityFragment().apply {
                arguments = Bundle().apply {
                    if (userId != null) putInt("userId", userId)
                }
            }
        }
    }
}
