import SwiftUI

/// Expands until `maxHeight`, then turns on internal scrolling and
/// always auto‑scrolls to keep the caret visible.
struct GrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat
    var maxHeight: CGFloat          // hard cap (e.g. 120 pt)

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = false               // will enable later if needed
        tv.font = UIFont(name: "Nasalization-Regular", size: 16)
        tv.backgroundColor = .clear
        tv.textColor = UIColor(Color.sl_textPrimary)
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }

        // Measure the natural height the text needs
        let fitting = CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fitting)

        // Toggle scrolling based on whether we exceed the cap
        uiView.isScrollEnabled = size.height > maxHeight

        // Invalidate so SwiftUI re‑reads intrinsicContentSize
        uiView.invalidateIntrinsicContentSize()

        // If scrolling is on, make sure the caret is visible
        if uiView.isScrollEnabled {
            context.coordinator.scrollCaretVisible(in: uiView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextEditor
        init(parent: GrowingTextEditor) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            tv.invalidateIntrinsicContentSize()
            if tv.isScrollEnabled { scrollCaretVisible(in: tv) }
        }

        /// Scroll so the insertion caret is always on‑screen
        func scrollCaretVisible(in tv: UITextView) {
            guard let range = tv.selectedTextRange else { return }
            let caret = tv.caretRect(for: range.end)
            tv.scrollRectToVisible(caret, animated: false)
        }

        // Clamp intrinsic size so SwiftUI honours min/max
        override func value(forKey key: String) -> Any? {
            if key == "intrinsicContentSize",
               let raw = super.value(forKey: key) as? CGSize {
                let h = max(parent.minHeight, min(raw.height, parent.maxHeight))
                return CGSize(width: raw.width, height: h)
            }
            return super.value(forKey: key)
        }
    }
}
