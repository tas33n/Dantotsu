package ani.dantotsu.others

import android.animation.ObjectAnimator
import android.graphics.Bitmap
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import ani.dantotsu.BottomSheetDialogFragment
import ani.dantotsu.FileUrl
import ani.dantotsu.R
import ani.dantotsu.databinding.BottomSheetImageBinding
import ani.dantotsu.openLinkInBrowser
import ani.dantotsu.saveImageToDownloads
import ani.dantotsu.setSafeOnClickListener
import ani.dantotsu.shareImage
import ani.dantotsu.snackString
import ani.dantotsu.toast
import ani.dantotsu.util.StoragePermissions.Companion.downloadsPermission
import com.bumptech.glide.Glide
import com.bumptech.glide.load.resource.bitmap.BitmapTransformation
import com.davemorrissey.labs.subscaleview.ImageSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ImageViewDialog : BottomSheetDialogFragment() {

    private var _binding: BottomSheetImageBinding? = null
    private val binding get() = _binding!!

    private var reload = false
    private var _title: String? = null
    private var _image: FileUrl? = null
    private var _image2: FileUrl? = null

    var onReloadPressed: ((ImageViewDialog) -> Unit)? = null
    var trans1: List<BitmapTransformation>? = null
    var trans2: List<BitmapTransformation>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            _title = it.getString("title")?.replace(Regex("[\\\\/:*?\"<>|]"), "")
            reload = it.getBoolean("reload")
            _image = it.getSerializable("image") as? FileUrl
            _image2 = it.getSerializable("image2") as? FileUrl
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = BottomSheetImageBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        val (title, image, image2) = Triple(_title, _image, _image2)
        if (image == null || title == null) {
            dismiss()
            snackString(getString(R.string.error_getting_image_data))
            return
        }
        if (reload) {
            binding.bottomImageReload.visibility = View.VISIBLE
            binding.bottomImageReload.setSafeOnClickListener {
                onReloadPressed?.invoke(this)
            }
        }

        binding.bottomImageTitle.text = title
        binding.bottomImageReload.setOnLongClickListener {
            openLinkInBrowser(image.url)
            if (image2 != null) openLinkInBrowser(image2.url)
            true
        }
        val context = requireContext()

        viewLifecycleOwner.lifecycleScope.launch {
            val binding = _binding ?: return@launch

            val bitmap = withContext(Dispatchers.IO) {
                try {
                    Glide.with(context)
                        .asBitmap()
                        .load(image.url)
                        .submit()
                        .get()
                } catch (e: Exception) {
                    null
                }
            }

            if (bitmap != null) {
                binding.bottomImageShare.isEnabled = true
                binding.bottomImageSave.isEnabled = true
                binding.bottomImageSave.setOnClickListener {
                    if (downloadsPermission(context as AppCompatActivity))
                        saveImageToDownloads(title, bitmap, requireActivity())
                }
                binding.bottomImageShare.setOnClickListener {
                    shareImage(title, bitmap, requireContext())
                }

                binding.bottomImageView.setImage(ImageSource.cachedBitmap(bitmap))
                ObjectAnimator.ofFloat(binding.bottomImageView, "alpha", 0f, 1f).setDuration(400L)
                    .start()
                binding.bottomImageProgress.visibility = View.GONE
            } else {
                toast(context.getString(R.string.loading_image_failed))
                binding.bottomImageNo.visibility = View.VISIBLE
                binding.bottomImageProgress.visibility = View.GONE
            }
        }
    }

    override fun onDestroy() {
        _binding = null
        super.onDestroy()
    }

    companion object {
        fun newInstance(
            title: String,
            image: FileUrl,
            showReload: Boolean = false,
            image2: FileUrl?
        ) = ImageViewDialog().apply {
            arguments = Bundle().apply {
                putString("title", title)
                putBoolean("reload", showReload)
                putSerializable("image", image)
                putSerializable("image2", image2)
            }
        }

        fun newInstance(activity: FragmentActivity, title: String?, image: String?): Boolean {
            ImageViewDialog().apply {
                arguments = Bundle().apply {
                    putString("title", title ?: return false)
                    putSerializable("image", FileUrl(image ?: return false))
                }
                show(activity.supportFragmentManager, "image")
            }
            return true
        }
    }
}
