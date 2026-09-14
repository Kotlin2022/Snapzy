//
//  ScreenshotBorderApplier.swift
//  Snapzy
//
//  Expands a screenshot with an outward colored border and optional corner radius.
//

import AppKit
import CoreGraphics
import Foundation

enum ScreenshotBorderApplier {
  /// Applies an outward border when settings require it.
  /// - Parameters:
  ///   - image: Source screenshot pixels.
  ///   - settings: Preference-backed border configuration (points).
  ///   - scaleFactor: Points-to-pixels multiplier for the capture (typically 1 or 2).
  /// - Returns: Bordered image, or the original when the border should not apply.
  static func applyIfNeeded(
    _ image: CGImage,
    settings: ScreenshotBorderSettings,
    scaleFactor: CGFloat
  ) -> CGImage {
    guard settings.shouldApply else { return image }

    let scale = max(scaleFactor, 1)
    let borderWidth = max((settings.widthPoints * scale).rounded(), 1)
    let cornerRadius = max((settings.cornerRadiusPoints * scale).rounded(), 0)
    return apply(
      image,
      borderWidthPixels: borderWidth,
      cornerRadiusPixels: cornerRadius,
      color: settings.color
    )
  }

  static func apply(
    _ image: CGImage,
    borderWidthPixels: CGFloat,
    cornerRadiusPixels: CGFloat,
    color: NSColor
  ) -> CGImage {
    let border = max(borderWidthPixels.rounded(), 0)
    guard border > 0 else { return image }

    let contentWidth = CGFloat(image.width)
    let contentHeight = CGFloat(image.height)
    let outputWidth = Int((contentWidth + border * 2).rounded())
    let outputHeight = Int((contentHeight + border * 2).rounded())
    guard outputWidth > 0, outputHeight > 0 else { return image }

    let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
      data: nil,
      width: outputWidth,
      height: outputHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    ) else {
      return image
    }

    context.interpolationQuality = .high
    let outputBounds = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
    let outerRadius = min(max(cornerRadiusPixels, 0), min(outputBounds.width, outputBounds.height) / 2)
    let outerPath = CGPath(
      roundedRect: outputBounds,
      cornerWidth: outerRadius,
      cornerHeight: outerRadius,
      transform: nil
    )

    context.saveGState()
    context.addPath(outerPath)
    context.clip()
    context.setFillColor(color.usingColorSpace(.sRGB)?.cgColor ?? color.cgColor)
    context.fill(outputBounds)

    let contentRect = CGRect(x: border, y: border, width: contentWidth, height: contentHeight)
    let innerRadius = min(max(outerRadius - border, 0), min(contentRect.width, contentRect.height) / 2)
    let innerPath = CGPath(
      roundedRect: contentRect,
      cornerWidth: innerRadius,
      cornerHeight: innerRadius,
      transform: nil
    )
    context.addPath(innerPath)
    context.clip()
    context.draw(image, in: contentRect)
    context.restoreGState()

    return context.makeImage() ?? image
  }
}
