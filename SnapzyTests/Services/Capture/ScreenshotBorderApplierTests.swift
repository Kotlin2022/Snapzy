//
//  ScreenshotBorderApplierTests.swift
//  SnapzyTests
//

import AppKit
import CoreGraphics
import XCTest
@testable import Snapzy

final class ScreenshotBorderApplierTests: XCTestCase {
  func testApplyIfNeeded_disabledReturnsOriginalSize() throws {
    let source = try makeSolidImage(width: 40, height: 30, color: .red)
    let settings = ScreenshotBorderSettings(
      isEnabled: false,
      color: .white,
      widthPoints: 12,
      cornerRadiusPoints: 8
    )

    let result = ScreenshotBorderApplier.applyIfNeeded(source, settings: settings, scaleFactor: 2)

    XCTAssertEqual(result.width, source.width)
    XCTAssertEqual(result.height, source.height)
  }

  func testApplyIfNeeded_zeroWidthReturnsOriginalSize() throws {
    let source = try makeSolidImage(width: 40, height: 30, color: .red)
    let settings = ScreenshotBorderSettings(
      isEnabled: true,
      color: .white,
      widthPoints: 0,
      cornerRadiusPoints: 8
    )

    let result = ScreenshotBorderApplier.applyIfNeeded(source, settings: settings, scaleFactor: 2)

    XCTAssertEqual(result.width, source.width)
    XCTAssertEqual(result.height, source.height)
  }

  func testApplyIfNeeded_expandsByTwiceBorderInPixels() throws {
    let source = try makeSolidImage(width: 40, height: 30, color: .red)
    let settings = ScreenshotBorderSettings(
      isEnabled: true,
      color: .white,
      widthPoints: 10,
      cornerRadiusPoints: 6
    )

    let result = ScreenshotBorderApplier.applyIfNeeded(source, settings: settings, scaleFactor: 2)

    // 10pt * scale 2 = 20px border on each side
    XCTAssertEqual(result.width, 40 + 40)
    XCTAssertEqual(result.height, 30 + 40)
  }

  func testApply_largeCornerRadiusDoesNotCrash() throws {
    let source = try makeSolidImage(width: 20, height: 20, color: .blue)
    let result = ScreenshotBorderApplier.apply(
      source,
      borderWidthPixels: 8,
      cornerRadiusPixels: 200,
      color: .white
    )

    XCTAssertEqual(result.width, 36)
    XCTAssertEqual(result.height, 36)
  }

  func testSettings_clampsDimension() {
    XCTAssertEqual(ScreenshotBorderSettings.clampedDimension(-4), 0)
    XCTAssertEqual(ScreenshotBorderSettings.clampedDimension(12), 12)
    XCTAssertEqual(
      ScreenshotBorderSettings.clampedDimension(999),
      ScreenshotBorderSettings.maxDimensionPoints
    )
  }

  func testSettings_loadDefaultsWhenUnset() {
    let suiteName = "ScreenshotBorderSettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = ScreenshotBorderSettings.load(from: defaults)

    XCTAssertFalse(settings.isEnabled)
    XCTAssertEqual(settings.widthPoints, ScreenshotBorderSettings.defaultWidthPoints)
    XCTAssertEqual(settings.cornerRadiusPoints, ScreenshotBorderSettings.defaultCornerRadiusPoints)
    XCTAssertFalse(settings.shouldApply)
  }

  private func makeSolidImage(width: Int, height: Int, color: NSColor) throws -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      throw NSError(domain: "ScreenshotBorderApplierTests", code: 1)
    }
    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
      throw NSError(domain: "ScreenshotBorderApplierTests", code: 2)
    }
    return image
  }
}
