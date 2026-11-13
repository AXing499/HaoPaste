//
//  GlassSurface.swift
//  HaoPaste
//
//  macOS 26 Liquid Glass with a deterministic material fallback.
//
//  The glass view is created through the Objective-C runtime so the project
//  still builds with older Xcode/SDK combinations and gets the native glass
//  effect when the app runs on macOS 26.
//

import AppKit
import SwiftUI

enum GlassSurfaceFallback {
    case material
    case popover
}

enum GlassTransparency: String, CaseIterable, Identifiable, Sendable {
    case frosted
    case standard
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frosted: return L("磨砂")
        case .standard: return L("标准")
        case .clear: return L("通透")
        }
    }

    var usesClearStyle: Bool {
        self == .clear
    }

    var tintFactor: CGFloat {
        switch self {
        case .frosted: return 1
        case .standard: return 0.62
        case .clear: return 0.24
        }
    }
}

enum DebugGlass {
    static var disablesGlass: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["HAOPASTE_RENDER_GLASS"] == "1" {
            return false
        }
        return environment["HAOPASTE_RENDER_DISABLE_ANIMATIONS"] == "1"
    }
}

struct GlassSurfaceBackground: View {
    let cornerRadius: CGFloat
    var tint: NSColor?
    var fallback: GlassSurfaceFallback = .material

    @AppStorage(AppSettings.liquidGlassDefaultsKey)
    private var enabled = true
    @AppStorage(AppSettings.liquidGlassTransparencyDefaultsKey)
    private var transparencyRaw = GlassTransparency.clear.rawValue
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorSchemeContrast)
    private var contrast

    private var transparency: GlassTransparency {
        GlassTransparency(rawValue: transparencyRaw) ?? .clear
    }

    private var adjustedTint: NSColor? {
        guard let tint else { return nil }
        return tint.withAlphaComponent(
            tint.alphaComponent * transparency.tintFactor
        )
    }

    private var usesGlass: Bool {
        guard enabled,
              !reduceTransparency,
              contrast != .increased,
              !DebugGlass.disablesGlass,
              NSClassFromString("NSGlassEffectView") != nil
        else {
            return false
        }
        return true
    }

    var body: some View {
        if usesGlass {
            AppKitGlassBackground(
                cornerRadius: cornerRadius,
                tint: adjustedTint,
                style: transparency.usesClearStyle ? 1 : 0
            )
        } else {
            fallbackView
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        switch fallback {
        case .material:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        case .popover:
            ZStack {
                Theme.popoverBackground
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

private struct AppKitGlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat
    let tint: NSColor?
    let style: Int

    func makeNSView(context: Context) -> NSView {
        guard let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type else {
            return NSView()
        }
        let view = glassClass.init(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configure(view)
    }

    private func configure(_ view: NSView) {
        view.setValue(cornerRadius, forKey: "cornerRadius")
        view.setValue(tint, forKey: "tintColor")
        view.setValue(style, forKey: "style")
    }
}

extension View {
    func glassSurfaceBackground(
        cornerRadius: CGFloat,
        tint: NSColor? = nil,
        fallback: GlassSurfaceFallback = .material
    ) -> some View {
        background {
            GlassSurfaceBackground(
                cornerRadius: cornerRadius,
                tint: tint,
                fallback: fallback
            )
            .allowsHitTesting(false)
        }
    }
}
