package com.example.driveit_project

import android.content.Context
import android.util.AttributeSet
import android.widget.RelativeLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/** Applies the system top inset to uCrop's content, keeping its toolbar in layout flow. */
class InsetAwareCropRoot @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : RelativeLayout(context, attrs, defStyleAttr) {
    init {
        ViewCompat.setOnApplyWindowInsetsListener(this) { view, insets ->
            val statusBarInset = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top
            val cutoutInset = insets.getInsets(WindowInsetsCompat.Type.displayCutout()).top
            val topInset = maxOf(statusBarInset, cutoutInset)
            view.setPadding(view.paddingLeft, topInset, view.paddingRight, view.paddingBottom)
            insets
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        ViewCompat.requestApplyInsets(this)
    }
}
