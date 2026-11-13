//
//  HotkeyConflictTipLogicTests.swift
//  SnapzyTests
//

import XCTest
@testable import Snapzy

final class HotkeyConflictTipLogicTests: XCTestCase {
  func testTipMessage_includesFrontAppAndSecureInput() {
    let message = HotkeyConflictTipLogic.tipMessage(
      shortcutDisplay: "⌥A",
      frontmostAppName: "Terminal",
      systemConflictNames: [],
      secureInputEnabled: true,
      registrationFailed: false
    )
    XCTAssertTrue(message.contains("⌥A"), message)
    XCTAssertTrue(message.contains("Terminal"), message)
    XCTAssertTrue(
      message.contains("Secure") || message.contains("安全"),
      message
    )
  }

  func testTipMessage_includesSystemConflictsAndRegistrationFailure() {
    let message = HotkeyConflictTipLogic.tipMessage(
      shortcutDisplay: "⇧⌘4",
      frontmostAppName: nil,
      systemConflictNames: ["macOS Capture Area"],
      secureInputEnabled: false,
      registrationFailed: true
    )
    XCTAssertTrue(message.contains("⇧⌘4"), message)
    XCTAssertTrue(message.contains("macOS Capture Area"), message)
    XCTAssertTrue(
      message.contains("taken") || message.contains("占用") || message.contains("already"),
      message
    )
  }

  func testTipMessage_unknownWhenNoReasons() {
    let message = HotkeyConflictTipLogic.tipMessage(
      shortcutDisplay: "⌘⇧H",
      frontmostAppName: "  ",
      systemConflictNames: [],
      secureInputEnabled: false,
      registrationFailed: false
    )
    XCTAssertTrue(message.contains("⌘⇧H"), message)
  }
}
