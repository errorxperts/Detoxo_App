package com.errorxperts.detoxo.widget

import java.io.File
import org.json.JSONObject

/**
 * A file at [path] under the repo root, found by walking up from the working
 * directory (Gradle runs tests from `android/app`) — so a JVM test can read the
 * real bundled assets the app ships.
 */
internal fun repoFile(path: String): File {
    val start = File(System.getProperty("user.dir")!!).absoluteFile
    val root = generateSequence(start) { it.parentFile }
        .firstOrNull { File(it, "test/fixtures/home_widget_cases.json").exists() }
        ?: error("test/fixtures/home_widget_cases.json not found above $start")
    return File(root, path)
}

/** One of the shared `test/fixtures` files the Dart tests drive too. */
internal fun fixture(name: String): JSONObject = JSONObject(repoFile("test/fixtures/$name").readText())
