package com.tarek.wara2a.qwen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class StrictJsonObjectAccumulatorTest {
    @Test
    fun `captures one object and excludes trailing generated text`() {
        val accumulator = StrictJsonObjectAccumulator()

        assertNull(accumulator.add("  {\"merchant\":\"Al Noor\","))
        assertEquals(
            "{\"merchant\":\"Al Noor\",\"products\":[{\"name\":\"A}B\"}]}",
            accumulator.add(
                "\"products\":[{\"name\":\"A}B\"}]}"
                    + "{\"o\":14,\"t\":\"trailing junk\"}",
            ),
        )
    }

    @Test
    fun `does not hide markdown or commentary prefixes`() {
        assertNull(StrictJsonObjectAccumulator.extract("```json\n{\"a\":1}"))
        assertNull(StrictJsonObjectAccumulator.extract("result: {\"a\":1}"))
    }

    @Test
    fun `handles escaped quotes and backslashes`() {
        val json = """{"value":"a \"quoted\" value","path":"c:\\tmp"}"""
        assertEquals(
            json,
            StrictJsonObjectAccumulator.extract("$json trailing"),
        )
    }
}
