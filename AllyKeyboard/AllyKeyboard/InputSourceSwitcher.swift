//
//  InputSourceSwitcher.swift
//  AllyKeyboard
//
//  Cycles the system keyboard input source (language) via Text Input Source
//  Services, and reports the current language's region/flag.
//

import AppKit
import Carbon.HIToolbox

enum InputSourceSwitcher {

    /// Fires when the selected keyboard input source changes (incl. via system UI).
    static let changeNotification = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)

    /// Switch to the next enabled language in the cycle. Returns false if there is
    /// nothing to switch to (0 or 1 enabled source).
    @discardableResult
    static func selectNext() -> Bool {
        let list = selectableSources()
        guard list.count > 1,
              let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        let curID = sourceID(current)
        let idx = list.firstIndex { sourceID($0) == curID } ?? -1
        return TISSelectInputSource(list[(idx + 1) % list.count]) == noErr
    }

    /// The currently active keyboard input source.
    static func currentSource() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    /// The character a physical key produces under a given source's layout —
    /// used to relabel the on-screen keys to match the current language.
    static func character(forKeyCode keyCode: UInt16, shift: Bool, from source: TISInputSource?) -> String? {
        guard let source,
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPtr).takeUnretainedValue() as Data
        var result: String?
        layoutData.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let modifiers = UInt32(shift ? (shiftKey >> 8) : 0)
            let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), modifiers,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeyState, chars.count, &length, &chars)
            if status == noErr, length > 0 {
                result = String(utf16CodeUnits: chars, count: length)
            }
        }
        return result
    }

    /// Two-letter region code for a source's primary language (for flag assets),
    /// or nil if there is no mapping.
    static func regionCode(for source: TISInputSource?) -> String? {
        guard let source, let lang = primaryLanguage(source) else { return nil }
        return regionCodes[String(lang.prefix(2)).lowercased()]
    }

    /// Uppercased two-letter language code — text fallback when no flag exists (e.g. "EN").
    static func languageAbbrev(for source: TISInputSource?) -> String {
        guard let source, let lang = primaryLanguage(source) else { return "?" }
        return String(lang.prefix(2)).uppercased()
    }

    // MARK: - TIS helpers

    private static func selectableSources() -> [TISInputSource] {
        guard let cf = TISCreateInputSourceList(nil, false)?.takeRetainedValue(),
              let all = cf as? [TISInputSource] else { return [] }
        return all.filter { source in
            stringProperty(source, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String)
                && boolProperty(source, kTISPropertyInputSourceIsSelectCapable)
                && boolProperty(source, kTISPropertyInputSourceIsEnabled)
        }
    }

    private static func sourceID(_ s: TISInputSource) -> String {
        stringProperty(s, kTISPropertyInputSourceID) ?? ""
    }

    private static func primaryLanguage(_ s: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(s, kTISPropertyInputSourceLanguages) else { return nil }
        let langs = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as? [String]
        return langs?.first
    }

    private static func stringProperty(_ s: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(s, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func boolProperty(_ s: TISInputSource, _ key: CFString) -> Bool {
        guard let ptr = TISGetInputSourceProperty(s, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }

    /// Primary language (ISO 639) -> region code (ISO 3166) for flag assets.
    private static let regionCodes: [String: String] = [
        "en": "us", "ru": "ru", "be": "by", "uk": "ua", "kk": "kz", "de": "de",
        "fr": "fr", "es": "es", "it": "it", "pl": "pl", "pt": "pt", "nl": "nl",
        "tr": "tr", "ja": "jp", "ko": "kr", "zh": "cn", "ar": "sa", "he": "il",
        "cs": "cz", "sv": "se", "fi": "fi", "nb": "no", "nn": "no", "no": "no",
        "da": "dk", "el": "gr",
    ]
}
