package dev.a11y.probe

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Instrumentation
import android.app.UiAutomation
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.platform.app.InstrumentationRegistry
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckPreset
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityCheckResult.AccessibilityCheckResultType
import com.google.android.apps.common.testing.accessibility.framework.AccessibilityHierarchyCheckResult
import com.google.android.apps.common.testing.accessibility.framework.Parameters
import com.google.android.apps.common.testing.accessibility.framework.uielement.AccessibilityHierarchyAndroid
import com.google.android.apps.common.testing.accessibility.framework.utils.contrast.BitmapImage
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Test
import java.io.File
import java.util.Locale
import java.util.concurrent.TimeoutException
import kotlin.math.roundToLong

class A11yProbeTest {

    private class Walked(val path: String, val node: AccessibilityNodeInfo, val bounds: Rect)

    @Test
    fun dump() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val args = InstrumentationRegistry.getArguments()
        val targetPackage = requireNotNull(args.getString("targetPackage")) {
            "missing instrumentation argument targetPackage"
        }

        val automation = instrumentation.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        automation.serviceInfo = automation.serviceInfo.apply {
            flags = flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        // Connecting turns accessibility on: the window list and Flutter's semantics tree appear only after that.
        try {
            automation.waitForIdle(IDLE_MS, IDLE_TIMEOUT_MS)
        } catch (_: TimeoutException) {
            // The app keeps sending events (e.g. an animation); read what is there now.
        }

        val root = automation.windows.firstNotNullOfOrNull { window ->
            window.root?.takeIf { it.packageName?.toString() == targetPackage }
        } ?: error("no window of $targetPackage on screen; bring the app to the foreground")

        val scale = Resources.getSystem().displayMetrics.densityDpi / 160.0
        val walked = mutableListOf<Walked>()
        walk(root, "0", walked)

        val screenshot = requireNotNull(automation.takeScreenshot()) { "screenshot failed" }
        // ATF reads pixels, which a hardware bitmap (returned by some Android versions) does not allow.
        val bitmap = screenshot.copy(Bitmap.Config.ARGB_8888, false)

        val hierarchy = AccessibilityHierarchyAndroid.newBuilder(root, instrumentation.targetContext).build()
        val parameters = Parameters().apply { putScreenCapture(BitmapImage(bitmap)) }
        val results = AccessibilityCheckPreset.getAccessibilityHierarchyChecksForPreset(AccessibilityCheckPreset.LATEST)
            .flatMap { it.runCheckOnHierarchy(hierarchy, null, parameters) }

        val json = JSONObject()
            .put("schema", "a11y-native/v1")
            .put("platform", "android")
            .put("device", args.getString("device", ""))
            .put("app", targetPackage)
            .put(
                "screen",
                JSONObject()
                    .put("width", round1(bitmap.width / scale))
                    .put("height", round1(bitmap.height / scale))
                    .put("scale", scale),
            )
            .put("nodes", JSONArray(walked.map { nodeJson(it, scale) }))
            .put("issues", JSONArray(results.mapNotNull { issueJson(it, walked, scale) }))

        val file = File(instrumentation.targetContext.getExternalFilesDir(null), "a11y-native.json")
        file.writeText(json.toString(2))
        val status = Bundle().apply {
            putString(Instrumentation.REPORT_KEY_STREAMRESULT, "A11Y_NATIVE_JSON_PATH=${file.absolutePath}\n")
        }
        instrumentation.sendStatus(STATUS_CODE, status)
    }

    private fun walk(node: AccessibilityNodeInfo, path: String, out: MutableList<Walked>) {
        out += Walked(path, node, Rect().also(node::getBoundsInScreen))
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { walk(it, "$path.$i", out) }
        }
    }

    private fun nodeJson(walked: Walked, scale: Double): JSONObject {
        val node = walked.node
        val className = node.className?.toString().orEmpty()
        val text = node.text?.toString().orEmpty()
        val label = node.contentDescription?.toString().orEmpty().ifEmpty { if (node.isEditable) "" else text }
        val clickable = node.isClickable || node.isLongClickable
        return JSONObject()
            .put("path", walked.path)
            .put("nativeType", className)
            .put("role", role(className, clickable, node.isHeading, label))
            .put("label", label)
            .put("value", if (node.isEditable) text else node.stateDescription?.toString().orEmpty())
            .put("hint", node.hintText?.toString().orEmpty())
            .put("identifier", node.viewIdResourceName.orEmpty())
            .put("rect", walked.bounds.let { rectJson(it.left, it.top, it.width(), it.height(), scale) })
            .put("focusable", node.isFocusable || node.isScreenReaderFocusable)
            .put("clickable", clickable)
            .put("enabled", node.isEnabled)
            .put("selected", node.isSelected)
            .put("checked", if (node.isCheckable) checked(node) else JSONObject.NULL)
            .put("heading", node.isHeading)
    }

    // The spec reads isChecked; its replacement getChecked() needs API 36.
    @Suppress("DEPRECATION")
    private fun checked(node: AccessibilityNodeInfo) = node.isChecked

    private fun role(className: String, clickable: Boolean, heading: Boolean, label: String): String =
        when (className.substringAfterLast('.')) {
            "EditText" -> "textField"
            "CheckBox" -> "checkbox"
            "RadioButton" -> "radio"
            "Switch", "ToggleButton" -> "switch"
            "SeekBar" -> "slider"
            "ImageView" -> "image"
            "Button", "ImageButton" -> "button"
            else -> when {
                clickable -> "button"
                heading -> "header"
                label.isNotEmpty() -> "text"
                else -> "other"
            }
        }

    private fun issueJson(result: AccessibilityHierarchyCheckResult, walked: List<Walked>, scale: Double): JSONObject? {
        val severity = when (result.type) {
            AccessibilityCheckResultType.ERROR -> "error"
            AccessibilityCheckResultType.WARNING -> "warning"
            AccessibilityCheckResultType.INFO -> "info"
            else -> return null
        }
        val element = result.element
        val bounds = element?.boundsInScreen
        // Several nodes can share bounds (a container and its only child); prefer the same class, then the deepest.
        val node = bounds?.let { b ->
            val sameBounds = walked.filter { it.bounds == Rect(b.left, b.top, b.right, b.bottom) }
            val className = element.className?.toString()
            sameBounds.lastOrNull { it.node.className?.toString() == className } ?: sameBounds.lastOrNull()
        }
        return JSONObject()
            .put("source", "atf")
            .put("check", result.sourceCheckClass.simpleName)
            .put("severity", severity)
            .put("message", result.getMessage(Locale.ENGLISH).toString())
            .put("nodePath", node?.path ?: JSONObject.NULL)
            .put("rect", bounds?.let { rectJson(it.left, it.top, it.width, it.height, scale) } ?: JSONObject.NULL)
    }

    private fun rectJson(left: Int, top: Int, width: Int, height: Int, scale: Double) =
        JSONArray(listOf(left, top, width, height).map { round1(it / scale) })

    private fun round1(value: Double) = (value * 10).roundToLong() / 10.0

    private companion object {
        const val IDLE_MS = 500L
        const val IDLE_TIMEOUT_MS = 5_000L
        // Any code other than AndroidJUnitRunner's own (1, 0, -1..-4); `am instrument -w` prints the stream text.
        const val STATUS_CODE = 2
    }
}
