//
//  HexColor.swift
//  HaoPaste
//
//  Parsing and alternate representations for HEX clipboard values.
//

import SwiftUI

struct HexColor: Equatable {
    let red: Int
    let green: Int
    let blue: Int
    let alpha: Double

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        let characters = Array(value)
        let expanded: [Character]

        switch characters.count {
        case 3:
            expanded = characters.flatMap { [$0, $0] }
        case 4:
            expanded = characters.flatMap { [$0, $0] }
        case 6, 8:
            expanded = characters
        default:
            return nil
        }

        guard
            let red = Int(String(expanded[0...1]), radix: 16),
            let green = Int(String(expanded[2...3]), radix: 16),
            let blue = Int(String(expanded[4...5]), radix: 16)
        else {
            return nil
        }

        let alphaByte: Int
        if expanded.count == 8 {
            guard let parsedAlpha = Int(String(expanded[6...7]), radix: 16) else {
                return nil
            }
            alphaByte = parsedAlpha
        } else {
            alphaByte = 255
        }

        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = Double(alphaByte) / 255.0
    }

    var color: Color {
        Color(
            .sRGB,
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            opacity: alpha
        )
    }

    var normalizedHex: String {
        let base = String(format: "#%02X%02X%02X", red, green, blue)
        guard alpha < 1 else { return base }
        return base + String(format: "%02X", Int((alpha * 255).rounded()))
    }

    var rgbString: String {
        if alpha < 1 {
            return "rgba(\(red), \(green), \(blue), \(alphaText))"
        }
        return "rgb(\(red), \(green), \(blue))"
    }

    var hslString: String {
        let red = Double(red) / 255.0
        let green = Double(green) / 255.0
        let blue = Double(blue) / 255.0
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let lightness = (maximum + minimum) / 2.0

        var hue: Double = 0
        var saturation: Double = 0

        if delta > 0 {
            saturation = lightness > 0.5
                ? delta / (2.0 - maximum - minimum)
                : delta / (maximum + minimum)

            switch maximum {
            case red:
                hue = (green - blue) / delta + (green < blue ? 6 : 0)
            case green:
                hue = (blue - red) / delta + 2
            default:
                hue = (red - green) / delta + 4
            }

            hue /= 6
        }

        let hueDegrees = Int((hue * 360).rounded()) % 360
        let saturationPercent = Int((saturation * 100).rounded())
        let lightnessPercent = Int((lightness * 100).rounded())

        if alpha < 1 {
            return "hsla(\(hueDegrees), \(saturationPercent)%, \(lightnessPercent)%, \(alphaText))"
        }
        return "hsl(\(hueDegrees), \(saturationPercent)%, \(lightnessPercent)%)"
    }

    private var alphaText: String {
        var text = String(format: "%.2f", alpha)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }
}
