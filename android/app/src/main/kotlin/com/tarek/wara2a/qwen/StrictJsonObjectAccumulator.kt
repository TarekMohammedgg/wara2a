package com.tarek.wara2a.qwen

/**
 * Captures the first complete top-level JSON object from streaming model text.
 *
 * Leading whitespace is allowed. Any other prefix remains invalid so the Dart
 * validator can reject commentary or markdown instead of silently repairing it.
 */
internal class StrictJsonObjectAccumulator {
    private val buffer = StringBuilder()

    @Volatile
    var completeJson: String? = null
        private set

    @Synchronized
    fun add(chunk: String): String? {
        completeJson?.let { return it }
        buffer.append(chunk)
        return extract(buffer.toString())?.also { completeJson = it }
    }

    companion object {
        fun extract(source: String): String? {
            val start = source.indexOfFirst { !it.isWhitespace() }
            if (start < 0 || source[start] != '{') return null
            var depth = 0
            var inString = false
            var escaped = false
            for (index in start until source.length) {
                val character = source[index]
                if (inString) {
                    when {
                        escaped -> escaped = false
                        character == '\\' -> escaped = true
                        character == '"' -> inString = false
                    }
                    continue
                }
                when (character) {
                    '"' -> inString = true
                    '{' -> depth++
                    '}' -> {
                        depth--
                        if (depth == 0) {
                            return source.substring(start, index + 1)
                        }
                        if (depth < 0) return null
                    }
                }
            }
            return null
        }
    }
}
