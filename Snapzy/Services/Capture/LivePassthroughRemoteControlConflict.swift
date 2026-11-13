//
//  LivePassthroughRemoteControlConflict.swift
//  Snapzy
//
//  Detects remote-control agents that fight the live-passthrough CGEvent tap
//  (consumes mouse events + hides the system cursor). UU Remote's helpers do not
//  register as NSRunningApplication, so detection walks process executable paths.
//

import Darwin
import Foundation

enum LivePassthroughRemoteControlConflict {
  /// Path substrings that identify known conflicting agents. Matched against
  /// `proc_pidpath` output (full executable path).
  static let conflictingPathMarkers: [String] = [
    "UURemote.app/",
    "/ToDesk",
    "SunloginClient",
    "/RustDesk",
    // DingTalk meeting helper — hides/steals pointer events while Snapzy has hidden
    // the system cursor, so selection looks frozen ("mouse can't move"). Match Tblive
    // only; DingTalk.app itself stays resident for chat and must not force this path.
    "Tblive.app/",
  ]

  /// UU installs a LaunchDaemon that keeps `UURemoteDaemon` alive forever. Matching that
  /// path as a conflict forces remote-compat polling on every local capture and mid-drag
  /// hitch. Ignore the idle daemon; session helpers under `UURemote.app/` still match.
  /// ponytail: if active UU remote freezes selection again, add the session helper path
  /// (not the daemon) to markers / an allowlist here.
  static let ignoredPathMarkers: [String] = [
    "UURemoteDaemon",
  ]

  /// Returns the first matching marker among `paths`, or `nil` when none conflict.
  static func matchingMarker(
    in paths: some Sequence<String>,
    markers: [String] = conflictingPathMarkers,
    ignoredMarkers: [String] = ignoredPathMarkers
  ) -> String? {
    for path in paths {
      if ignoredMarkers.contains(where: { path.contains($0) }) {
        continue
      }
      for marker in markers where path.contains(marker) {
        return marker
      }
    }
    return nil
  }

  /// True when a known remote-control helper is running on this Mac.
  static func isPresent(
    runningExecutablePaths: () -> [String] = { listRunningExecutablePaths() }
  ) -> Bool {
    matchingMarker(in: runningExecutablePaths()) != nil
  }

  /// Inline area-annotate hides the system cursor and draws a crosshair from SwiftUI
  /// hover/drag events. Remote agents often deliver pointer motion without those events,
  /// so the drawn crosshair freezes while the real cursor stays hidden — looks stuck.
  /// Skip the hide (and poll pointer instead) whenever a conflict is present.
  static func shouldHideSystemCursorDuringSelection(
    hasRemoteControlConflict: Bool
  ) -> Bool {
    !hasRemoteControlConflict
  }

  /// Snapshot every process executable path via libproc. Soft-fails to `[]` if the
  /// buffer is too small or a path cannot be resolved.
  static func listRunningExecutablePaths() -> [String] {
    let pidByteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
    guard pidByteCount > 0 else { return [] }

    let pidCapacity = Int(pidByteCount) / MemoryLayout<pid_t>.size
    var pids = [pid_t](repeating: 0, count: pidCapacity)
    let filledBytes = pids.withUnsafeMutableBufferPointer { buffer in
      proc_listpids(
        UInt32(PROC_ALL_PIDS),
        0,
        buffer.baseAddress,
        Int32(buffer.count * MemoryLayout<pid_t>.size)
      )
    }
    guard filledBytes > 0 else { return [] }

    let filledCount = Int(filledBytes) / MemoryLayout<pid_t>.size
    var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    var paths: [String] = []
    paths.reserveCapacity(filledCount)

    for index in 0..<filledCount {
      let pid = pids[index]
      guard pid > 0 else { continue }
      let length = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
      guard length > 0 else { continue }
      paths.append(String(cString: pathBuffer))
    }
    return paths
  }
}
