//
//  AppSettings.swift
//  douziapp
//
//  アプリ設定管理（UserDefaults/AppStorage）
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    // MARK: - 言語設定

    @AppStorage("sourceLanguage") var sourceLanguage: String = "en-US"
    @AppStorage("targetLanguage") var targetLanguage: String = "ja-JP"

    // MARK: - 音声設定

    @AppStorage("autoSpeak") var autoSpeak: Bool = true
    @AppStorage("speechRate") var speechRate: Double = 0.5
    @AppStorage("volume") var volume: Double = 1.0

    // MARK: - 一般設定

    @AppStorage("darkMode") var darkMode: DarkModeSetting = .system
    @AppStorage("historyRetentionDays") var historyRetentionDays: Int = 30
    @AppStorage("backgroundEnabled") var backgroundEnabled: Bool = true
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true

    // MARK: - 統計

    @AppStorage("totalTranslations") var totalTranslations: Int = 0
    @AppStorage("totalMinutes") var totalMinutes: Double = 0

    // MARK: - Computed Properties

    var sourceLanguageLocale: Locale {
        Locale(identifier: sourceLanguage)
    }

    var targetLanguageLocale: Locale {
        Locale(identifier: targetLanguage)
    }

    // MARK: - Methods

    func resetToDefaults() {
        sourceLanguage = "en-US"
        targetLanguage = "ja-JP"
        autoSpeak = true
        speechRate = 0.5
        volume = 1.0
        darkMode = .system
        historyRetentionDays = 30
        backgroundEnabled = true
        hapticFeedback = true
    }

    func incrementTranslationCount() {
        totalTranslations += 1
    }

    func addMinutes(_ minutes: Double) {
        totalMinutes += minutes
    }
}

// MARK: - Dark Mode Setting

enum DarkModeSetting: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "システム設定に従う"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - RawRepresentable for AppStorage

extension DarkModeSetting: RawRepresentable {
    init?(rawValue: String) {
        switch rawValue {
        case "system": self = .system
        case "light": self = .light
        case "dark": self = .dark
        default: return nil
        }
    }
}
