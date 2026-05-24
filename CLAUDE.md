# AllyKeyboard — Project Context for Claude Code

## What is this project
macOS virtual keyboard for head tracker / headmouse users.
Floating window + clickable word suggestions, inspired by Hot Virtual Keyboard (Windows).
Personal use project, not for App Store distribution.

## Tech stack
- Language: Swift
- Framework: **AppKit** (NOT SwiftUI)
- Key APIs: CGEvent (key simulation), AXUIElement (accessibility), NSWindow.level = .floating
- Xcode project: `AllyKeyboard/AllyKeyboard.xcodeproj`

## Development workflow
- Code lives at: `~/projects/ally-keyboard`
- Edit files here → git push → MacInCloud pulls and builds in Xcode
- Always run `git pull` before starting work

## Building & testing
```bash
cd ~/projects/ally-keyboard/AllyKeyboard
xcodebuild -scheme AllyKeyboard -configuration Debug build
```

## Current state
See PLAN.md for full implementation plan and current progress.
Phase 0 is complete. Next: Phase 1 — floating keyboard window.

## User
- Uses head tracker / headmouse device
- Works on MacInCloud via RDP/SSH (Pay-As-You-Go, weekends only)
- Familiar with Git

## Preferences
- Commit messages in English
- Edit files directly (no need to show diff first)
- AppKit only, no SwiftUI
