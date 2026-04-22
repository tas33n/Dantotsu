package eu.kanade.tachiyomi.extension.util

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import ani.dantotsu.media.MediaType
import ani.dantotsu.util.Logger
import eu.kanade.tachiyomi.extension.anime.model.AnimeExtension
import eu.kanade.tachiyomi.extension.anime.model.AnimeLoadResult
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import tachiyomi.core.util.lang.launchNow

/**
 * Broadcast receiver that listens for the system's packages installed, updated or removed, and only
 * notifies the given [listener] when the package is an extension.
 *
 * @param listener The listener that should be notified of extension installation events.
 */
internal class ExtensionInstallReceiver : BroadcastReceiver() {

    private var animeListener: AnimeListener? = null
    private var type: MediaType? = null

    /**
     * Registers this broadcast receiver
     */
    fun register(context: Context) {
        ContextCompat.registerReceiver(context, this, filter, ContextCompat.RECEIVER_EXPORTED)
    }

    fun setAnimeListener(listener: AnimeListener): ExtensionInstallReceiver {
        this.type = MediaType.ANIME
        animeListener = listener
        return this
    }

    /**
     * Called when one of the events of the [filter] is received. When the package is an extension,
     * it's loaded in background and it notifies the [listener] when finished.
     */
    @OptIn(DelicateCoroutinesApi::class)
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_PACKAGE_ADDED -> {
                if (isReplacing(intent)) return

                launchNow {
                    if (type == MediaType.ANIME) {
                        when (val result = getAnimeExtensionFromIntent(context, intent)) {
                            is AnimeLoadResult.Success -> animeListener?.onExtensionInstalled(
                                result.extension
                            )

                            is AnimeLoadResult.Untrusted -> animeListener?.onExtensionUntrusted(
                                result.extension
                            )

                            else -> {}
                        }
                    }
                }
            }

            Intent.ACTION_PACKAGE_REPLACED -> {
                launchNow {
                    if (type == MediaType.ANIME) {
                        when (val result = getAnimeExtensionFromIntent(context, intent)) {
                            is AnimeLoadResult.Success -> animeListener?.onExtensionUpdated(
                                result.extension
                            )

                            else -> {}
                        }
                    }
                }
            }

            Intent.ACTION_PACKAGE_REMOVED -> {
                if (isReplacing(intent)) return

                val pkgName = getPackageNameFromIntent(intent)
                if (pkgName != null) {
                    if (type == MediaType.ANIME) {
                        animeListener?.onPackageUninstalled(pkgName)
                    }
                }
            }
        }
    }

    /**
     * Returns the extension triggered by the given intent.
     *
     * @param context The application context.
     * @param intent The intent containing the package name of the extension.
     */
    @OptIn(DelicateCoroutinesApi::class)
    private suspend fun getAnimeExtensionFromIntent(
        context: Context,
        intent: Intent?
    ): AnimeLoadResult {
        val pkgName = getPackageNameFromIntent(intent)
        if (pkgName == null) {
            Logger.log("Package name not found")
            return AnimeLoadResult.Error
        }
        return GlobalScope.async(Dispatchers.Default, CoroutineStart.DEFAULT) {
            ExtensionLoader.loadAnimeExtensionFromPkgName(
                context,
                pkgName,
            )
        }.await()
    }

    /**
     * Listener that receives extension installation events.
     */
    interface AnimeListener {
        fun onExtensionInstalled(extension: AnimeExtension.Installed)
        fun onExtensionUpdated(extension: AnimeExtension.Installed)
        fun onExtensionUntrusted(extension: AnimeExtension.Untrusted)
        fun onPackageUninstalled(pkgName: String)
    }

    companion object {

        /**
         * Returns the intent filter this receiver should subscribe to.
         */
        val filter
            get() = IntentFilter().apply {
                priority = 100
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addAction(Intent.ACTION_PACKAGE_REPLACED)
                addAction(Intent.ACTION_PACKAGE_REMOVED)
                addDataScheme("package")
            }

        /**
         * Returns true if this package is performing an update.
         *
         * @param intent The intent that triggered the event.
         */
        fun isReplacing(intent: Intent): Boolean {
            return intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
        }


        /**
         * Returns the package name of the installed, updated or removed application.
         */
        fun getPackageNameFromIntent(intent: Intent?): String? {
            return intent?.data?.encodedSchemeSpecificPart ?: return null
        }
    }
}
