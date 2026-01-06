//
//  TranslationService.swift
//  douziapp
//
//  翻訳API連携サービス（DeepL/Google Translation対応）
//

import Foundation

@MainActor
class TranslationService: ObservableObject {
    // MARK: - Published Properties

    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var error: TranslationError?

    // MARK: - Private Properties

    private var translateTask: Task<Void, Never>?
    private var lastTranslatedText: String = ""
    private let debounceDelay: TimeInterval = 0.5

    // API設定（実際の運用ではKeychain等で安全に管理）
    private let apiKey: String = ProcessInfo.processInfo.environment["DEEPL_API_KEY"] ?? ""
    private let apiEndpoint = "https://api-free.deepl.com/v2/translate"

    // MARK: - Public Methods

    /// テキストを翻訳
    func translate(text: String, from: Language = .english, to: Language = .japanese) async {
        // 空文字や同一テキストはスキップ
        guard !text.isEmpty, text != lastTranslatedText else { return }

        // 既存のタスクをキャンセル（デバウンス）
        translateTask?.cancel()

        translateTask = Task {
            // デバウンス待機
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            isTranslating = true
            defer { isTranslating = false }

            do {
                let result = try await performTranslation(text: text, from: from, to: to)
                if !Task.isCancelled {
                    translatedText = result
                    lastTranslatedText = text
                }
            } catch {
                if !Task.isCancelled {
                    self.error = .translationFailed(error.localizedDescription)
                    // フォールバック: ダミー翻訳（デモ用）
                    translatedText = fallbackTranslation(text: text)
                }
            }
        }
    }

    /// 翻訳結果をクリア
    func clearTranslation() {
        translatedText = ""
        lastTranslatedText = ""
    }

    // MARK: - Private Methods

    private func performTranslation(text: String, from: Language, to: Language) async throws -> String {
        // APIキーが設定されていない場合はフォールバック
        guard !apiKey.isEmpty else {
            return fallbackTranslation(text: text)
        }

        // DeepL API リクエスト
        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text)&source_lang=\(from.code)&target_lang=\(to.code)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TranslationError.apiError
        }

        let deeplResponse = try JSONDecoder().decode(DeepLResponse.self, from: data)
        return deeplResponse.translations.first?.text ?? ""
    }

    /// フォールバック翻訳（デモ用・オフライン用）
    private func fallbackTranslation(text: String) -> String {
        // 簡易的な辞書ベース翻訳（デモ用）
        let translations: [String: String] = [
            "hello": "こんにちは",
            "goodbye": "さようなら",
            "thank you": "ありがとうございます",
            "yes": "はい",
            "no": "いいえ",
            "good morning": "おはようございます",
            "good evening": "こんばんは",
            "how are you": "お元気ですか",
            "nice to meet you": "はじめまして",
            "please": "お願いします",
            "sorry": "すみません",
            "excuse me": "失礼します"
        ]

        let lowercased = text.lowercased()
        for (english, japanese) in translations {
            if lowercased.contains(english) {
                return japanese
            }
        }

        // マッチしない場合は「翻訳中...」を返す
        return "【翻訳】\(text)"
    }
}

// MARK: - Language Enum

enum Language: String, CaseIterable {
    case english
    case japanese
    case chinese
    case korean
    case french
    case spanish
    case vietnamese

    var code: String {
        switch self {
        case .english: return "EN"
        case .japanese: return "JA"
        case .chinese: return "ZH"
        case .korean: return "KO"
        case .french: return "FR"
        case .spanish: return "ES"
        case .vietnamese: return "VI"
        }
    }

    var displayName: String {
        switch self {
        case .english: return "英語"
        case .japanese: return "日本語"
        case .chinese: return "中国語"
        case .korean: return "韓国語"
        case .french: return "フランス語"
        case .spanish: return "スペイン語"
        case .vietnamese: return "ベトナム語"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .korean: return "🇰🇷"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .vietnamese: return "🇻🇳"
        }
    }
}

// MARK: - API Response Models

struct DeepLResponse: Codable {
    let translations: [DeepLTranslation]
}

struct DeepLTranslation: Codable {
    let detectedSourceLanguage: String?
    let text: String

    enum CodingKeys: String, CodingKey {
        case detectedSourceLanguage = "detected_source_language"
        case text
    }
}

// MARK: - Error Types

enum TranslationError: LocalizedError {
    case apiError
    case invalidResponse
    case translationFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiError:
            return "翻訳APIエラー"
        case .invalidResponse:
            return "無効なレスポンス"
        case .translationFailed(let message):
            return "翻訳エラー: \(message)"
        }
    }
}
