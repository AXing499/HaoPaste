//
//  ImageThumbnailView.swift
//  HaoPaste
//
//  Loads cached image thumbnails without blocking row layout.
//

import AppKit
import SwiftUI

struct ImageThumbnailView: View {
    let url: URL
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.iconCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.055))

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .transition(.opacity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: Theme.iconCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.iconCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: Theme.hairline)
        }
        .task(id: url) {
            image = NSImage(contentsOf: url)
        }
    }
}
