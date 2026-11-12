//
//  TranslationSourceEditor.swift
//  HaoPaste
//
//  Editable source text for the selection translation card. Return submits,
//  while Shift-Return inserts a newline at the insertion point.
//

import AppKit
import SwiftUI

struct TranslationSourceEditor: NSViewRepresentable {
    @Binding var text: String
    let onTranslate: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = SourceTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = Self.font
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.string = text
        textView.onTranslate = onTranslate
        textView.setAccessibilityLabel(L("原文"))

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SourceTextView else {
            return
        }

        context.coordinator.parent = self
        textView.onTranslate = onTranslate
        textView.setAccessibilityLabel(L("原文"))

        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(
                NSRange(location: (text as NSString).length, length: 0)
            )
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationSourceEditor

        init(_ parent: TranslationSourceEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.text = textView.string
        }
    }

    private static let font: NSFont = {
        let size: CGFloat = 11
        let base = NSFont.systemFont(ofSize: size)
        guard
            let descriptor = base.fontDescriptor.withDesign(.rounded),
            let font = NSFont(descriptor: descriptor, size: size)
        else {
            return base
        }
        return font
    }()
}

private final class SourceTextView: NSTextView {
    var onTranslate: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        if hasMarkedText() {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            let flags = event.modifierFlags.intersection(
                .deviceIndependentFlagsMask
            )
            if flags.contains(.shift) {
                insertNewline(nil)
            } else if let onTranslate {
                onTranslate(string)
            } else {
                insertNewline(nil)
            }
            return
        }

        super.keyDown(with: event)
    }
}
