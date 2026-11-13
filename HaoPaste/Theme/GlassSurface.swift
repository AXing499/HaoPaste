//
//  GlassSurface.swift
//  HaoPaste
//
//  macOS 26 Liquid Glass with a deterministic material fallback.
//

import AppKit
import SwiftUI

enum GlassSurfaceFallback {
    case material
    case popover
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

struct GlassSurfaceBackground<S: Shape>: View {
    let shape: S
    var tint: Color?
    var fallback: GlassSurfaceFallback = .material

    @AppStorage(AppSettings.liquidGlassDefaultsKey)
    private var enabled = true
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorSchemeContrast)
    private var contrast

    var body: some View {
        if #available(macOS 26.0, *),
           enabled,
           !reduceTransparency,
           contrast != .increased,
           !DebugGlass.disablesGlass {
            Color.clear
                .glassEffect(.regular.tint(tint), in: shape)
        } else {
            fallbackView
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        switch fallback {
        case .material:
            shape.fill(.regularMaterial)
        case .popover:
            ZStack {
                Theme.popoverBackground
                shape.fill(.regularMaterial)
            }
            .clipShape(shape)
        }
    }
}

extension View {
    func glassSurfaceBackground<S: Shape>(
        _ shape: S,
        tint: Color? = nil,
        fallback: GlassSurfaceFallback = .material
    ) -> some View {
        background {
            GlassSurfaceBackground(
                shape: shape,
                tint: tint,
                fallback: fallback
            )
            .allowsHitTesting(false)
        }
    }
}
