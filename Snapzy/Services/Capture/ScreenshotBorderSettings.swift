//
//  ScreenshotBorderSettings.swift
//  Snapzy
//
//  Preference values for the optional outward screenshot border.
//

import AppKit
import Foundation

struct ScreenshotBorderSettings: Equatable {
  var isEnabled: Bool
  var color: NSColor
  var widthPoints: CGFloat
  var cornerRadiusPoints: CGFloat

  static let defaultWidthPoints: CGFloat = 12
  static let defaultCornerRadiusPoints: CGFloat = 16
  static let maxDimensionPoints: CGFloat = 128
  static let defaultColor = NSColor.white

  static let disabled = ScreenshotBorderSettings(
    isEnabled: false,
    color: defaultColor,
    widthPoints: defaultWidthPoints,
    cornerRadiusPoints: defaultCornerRadiusPoints
  )

  var shouldApply: Bool {
    isEnabled && widthPoints > 0
  }

  static func load(from defaults: UserDefaults = .standard) -> ScreenshotBorderSettings {
    let isEnabled = defaults.object(forKey: PreferencesKeys.screenshotBorderEnabled) as? Bool ?? false
    let width = clampedDimension(
      defaults.object(forKey: PreferencesKeys.screenshotBorderWidth) as? Double
        ?? Double(defaultWidthPoints)
    )
    let cornerRadius = clampedDimension(
      defaults.object(forKey: PreferencesKeys.screenshotBorderCornerRadius) as? Double
        ?? Double(defaultCornerRadiusPoints)
    )
    return ScreenshotBorderSettings(
      isEnabled: isEnabled,
      color: loadColor(from: defaults) ?? defaultColor,
      widthPoints: width,
      cornerRadiusPoints: cornerRadius
    )
  }

  static func clampedDimension(_ value: Double) -> CGFloat {
    CGFloat(min(max(value, 0), Double(maxDimensionPoints)))
  }

  private static func loadColor(from defaults: UserDefaults) -> NSColor? {
    guard let data = defaults.data(forKey: PreferencesKeys.screenshotBorderColor),
          let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
      return nil
    }
    return color
  }
}
