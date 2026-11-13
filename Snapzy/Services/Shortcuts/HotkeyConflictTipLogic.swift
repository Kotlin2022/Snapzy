//
//  HotkeyConflictTipLogic.swift
//  Snapzy
//
//  Pure copy builder for “hotkey pressed but Snapzy did not handle it” tips.
//

import Foundation

enum HotkeyConflictTipLogic {
  /// Builds a single toast line naming likely conflict sources.
  static func tipMessage(
    shortcutDisplay: String,
    frontmostAppName: String?,
    systemConflictNames: [String],
    secureInputEnabled: Bool,
    registrationFailed: Bool
  ) -> String {
    var reasons: [String] = []

    if secureInputEnabled {
      reasons.append(L10n.PreferencesShortcuts.hotkeyConflictReasonSecureInput)
    }

    if registrationFailed {
      reasons.append(L10n.PreferencesShortcuts.hotkeyConflictReasonAlreadyTaken)
    }

    let trimmedApp = frontmostAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedApp.isEmpty {
      reasons.append(L10n.PreferencesShortcuts.hotkeyConflictReasonFrontApp(trimmedApp))
    }

    for name in systemConflictNames where !name.isEmpty {
      reasons.append(name)
    }

    if reasons.isEmpty {
      return L10n.PreferencesShortcuts.hotkeyConflictTipUnknown(shortcutDisplay)
    }

    let joined = reasons.joined(separator: L10n.PreferencesShortcuts.hotkeyConflictReasonSeparator)
    return L10n.PreferencesShortcuts.hotkeyConflictTip(shortcutDisplay, joined)
  }
}
