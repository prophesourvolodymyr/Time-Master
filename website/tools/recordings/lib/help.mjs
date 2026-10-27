import { SCENES } from "../scenes/index.mjs";

/** `node record.mjs --help`: what the pipeline does, the one-time simulator setup, and every command. */
export function help() {
  return `Records real screen clips of the Tmax iPhone app for the website.

Each scene reseeds the demo data (dates follow today, so record before local midnight), sets dark
appearance, the 9:41 status bar and a Vancouver location, drives the real app with an XCUITest driver at
human pace, records with simctl, trims to the first and last motion, and encodes H.264 High 720x1566 sRGB
clips (30 fps, faststart, silent) with first-frame posters into public/media/app. It then regenerates
src/content/app-clips.ts from the clips on disk. Raw masters go to raw/ (gitignored). Only the
"Tmax Web Recording" simulator is touched (override with TMAX_SIM_UDID).

Usage
  node record.mjs [clip-id ...]       record scenes (no ids: every scene, in delivery order)
  node encode.mjs [clip-id ...]       re-encode from the raw masters with the stored trim
                                      (no ids: regenerate the catalog only)
  node drive.mjs start | stop | build start, stop or rebuild the XCUITest driver
  node drive.mjs '<json command>'...  run driver commands, for example
                                      '{"op":"query","type":"button","limit":80}' lists buttons on screen

Scenes
  ${SCENES.map((scene) => scene.id).join(", ")}

Requirements
  Xcode 26 with the iOS 26.5 simulator runtime, xcodegen, ffmpeg with libx264, Node 22, Python 3 with
  Pillow.

One-time setup
  xcrun simctl create "Tmax Web Recording" "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5
  xcrun simctl boot "Tmax Web Recording"
  # from the repo root
  xcodebuild -project TimeMaster.xcodeproj -scheme TimeMaster -configuration Debug \\
    -destination "platform=iOS Simulator,name=Tmax Web Recording" \\
    -derivedDataPath /tmp/tmax-web-recording-dd build
  xcrun simctl install "Tmax Web Recording" \\
    /tmp/tmax-web-recording-dd/Build/Products/Debug-iphonesimulator/TimeMaster.app

Pieces
  scenes/   scene scripts (prepare runs unrecorded, steps are recorded); points are iPhone 17 Pro points
  seed/     demo data builder and installer; covers come from the app's Ranked illustrations
  driver/   XCUITest driver (xcodegen project) serving JSON commands from /tmp/tmax-driver/inbox
  lib/      simulator, driver, encoder, plist and catalog helpers

Notes
  Preferences are written through the simulator's cfprefsd (defaults delete + import); editing the
  plist file directly lets cfprefsd write stale keys back. The driver switches off XCTest's automatic
  screen capture, which would otherwise record the hours-long driver test until the disk fills. Screens
  that never sit still need quiescence(false) and trim: "steps". If recordVideo writes an empty file,
  reboot the simulator and record again.
`;
}
