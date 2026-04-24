package ani.dantotsu.settings

interface SearchQueryHandler {
    fun updateContentBasedOnQuery(query: String?)
    fun notifyDataChanged() {}
}
