import SwiftUI

struct GrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var maxHeight: CGFloat = 120 // Set your max height (e.g., 4-5 lines)
    var minHeight: CGFloat = 38  // Your single line height

    // MARK: - UIViewRepresentable
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        // No constraints, no translatesAutoresizingMaskIntoConstraints needed
        
        tv.font = UIFont(name: "Nasalization-Regular", size: 16)!
        tv.backgroundColor = .clear
        tv.textColor = UIColor(Color.sl_textPrimary)
        
        // Adjust insets to your liking - this adds padding *inside* the text view
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        
        // Critical for wrapping and proper sizing
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainer.widthTracksTextView = true
        
        tv.showsHorizontalScrollIndicator = false
        tv.isScrollEnabled = false // Will be updated dynamically
        
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        tv.delegate = context.coordinator
        context.coordinator.textView = tv // Keep a weak reference
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update text if changed externally
        if uiView.text != self.text {
            uiView.text = self.text
            // Trigger a size check after external text change
            context.coordinator.recalculateHeight(for: uiView, parent: self)
        }
        
        // Ensure the coordinator has the latest parent values if needed
        context.coordinator.parent = self
        
        // Recalculate height during updates too, as width might change
        context.coordinator.recalculateHeight(for: uiView, parent: self)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: - Coordinator
    final class Coordinator: NSObject, UITextViewDelegate {
        weak var textView: UITextView?
        var parent: GrowingTextEditor

        init(parent: GrowingTextEditor) {
            self.parent = parent
        }

        /// Calculates the needed height and updates the scroll state & invalidates size.
        func recalculateHeight(for tv: UITextView, parent: GrowingTextEditor) {
            // Use sizeThatFits to get the ideal height
            let availableWidth = tv.bounds.width - tv.textContainerInset.left - tv.textContainerInset.right - (2 * tv.textContainer.lineFragmentPadding)
            
            // Only calculate if width is valid
            guard availableWidth > 0 else { return }

            let size = tv.sizeThatFits(CGSize(width: availableWidth, height: .infinity))
            
            let newHeight = max(parent.minHeight, min(parent.maxHeight, size.height))
            let shouldScroll = size.height > parent.maxHeight

            // Update scrolling only if it changed
            if tv.isScrollEnabled != shouldScroll {
                tv.isScrollEnabled = shouldScroll
            }

            // *** CRITICAL: Tell SwiftUI that the desired size changed ***
            // We do this *if* the calculated size (clamped) differs from the current frame height
            // OR if the scroll state changed (as that affects how SwiftUI treats it).
            // A simpler way is to just invalidate *every time* text changes,
            // letting SwiftUI optimize if needed.
           // tv.invalidateIntrinsicContentSize()
            
            // Keep caret visible if scrolling
            if abs(parent.height - newHeight) > 0.1 { // Use a small tolerance
                            DispatchQueue.main.async { // Ensure UI updates on main thread
                               self.parent.height = newHeight
                }
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Update the binding
            self.parent.text = textView.text
            // Ensure layout calculation happens
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            // Recalculate height and tell SwiftUI
            recalculateHeight(for: textView, parent: self.parent)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // This can also be used to keep caret visible
            if textView.isScrollEnabled, let range = textView.selectedTextRange {
                DispatchQueue.main.async {
                    textView.scrollRectToVisible(textView.caretRect(for: range.end), animated: false)
                }
            }
        }
    }
}
