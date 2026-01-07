//
//  TranslationService.swift
//  douziapp
//
//  翻訳API連携サービス - Google Apps Script経由で翻訳
//

import Foundation

@MainActor
class TranslationService: ObservableObject {
    // MARK: - Published Properties

    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - Private Properties

    private var translateTask: Task<Void, Never>?
    private var lastSourceText: String = ""
    private let debounceDelay: TimeInterval = 0.5

    // キャッシュ
    private var translationCache: [String: String] = [:]

    // MARK: - Public Methods

    // 現在の翻訳方向
    private var currentSourceLang: String = "en"
    private var currentTargetLang: String = "ja"

    /// テキストを翻訳（双方向対応）
    func translate(text: String, from sourceLang: String = "en", to targetLang: String = "ja") async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空文字はスキップ
        guard !trimmedText.isEmpty else { return }

        // 短すぎるテキストはスキップ（ノイズ防止）
        guard trimmedText.count >= 2 else { return }

        // 言語が変わったらキャッシュをクリア
        if sourceLang != currentSourceLang || targetLang != currentTargetLang {
            translationCache.removeAll()
            currentSourceLang = sourceLang
            currentTargetLang = targetLang
        }

        // 同一テキストはスキップ
        guard trimmedText != lastSourceText else { return }

        // キャッシュをチェック
        let cacheKey = "\(sourceLang)|\(targetLang)|\(trimmedText)"
        if let cached = translationCache[cacheKey] {
            translatedText = cached
            lastSourceText = trimmedText
            return
        }

        // 既存のタスクをキャンセル
        translateTask?.cancel()

        translateTask = Task {
            // デバウンス待機
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            isTranslating = true
            errorMessage = ""

            do {
                // LibreTranslate APIを使用
                let result = try await translateWithLibreTranslate(text: trimmedText, from: sourceLang, to: targetLang)

                if !Task.isCancelled {
                    translatedText = result
                    lastSourceText = trimmedText
                    translationCache[cacheKey] = result
                    print("✅ 翻訳成功 (\(sourceLang)→\(targetLang)): \(trimmedText) → \(result)")
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ 翻訳エラー: \(error)")
                    // フォールバック: MyMemory APIを試す
                    do {
                        let fallbackResult = try await translateWithMyMemory(text: trimmedText, from: sourceLang, to: targetLang)
                        translatedText = fallbackResult
                        lastSourceText = trimmedText
                        translationCache[cacheKey] = fallbackResult
                        print("✅ フォールバック翻訳成功: \(trimmedText) → \(fallbackResult)")
                    } catch {
                        errorMessage = "翻訳エラー"
                        translatedText = "翻訳できませんでした"
                    }
                }
            }

            isTranslating = false
        }
    }

    /// 翻訳結果をクリア
    func clearTranslation() {
        translatedText = ""
        lastSourceText = ""
        errorMessage = ""
    }

    // MARK: - LibreTranslate API (無料)

    private func translateWithLibreTranslate(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let url = URL(string: "https://libretranslate.com/translate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "q": text,
            "source": sourceLang,
            "target": targetLang,
            "format": "text"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.apiError
        }

        struct LibreTranslateResponse: Codable {
            let translatedText: String
        }

        let decoded = try JSONDecoder().decode(LibreTranslateResponse.self, from: data)
        return decoded.translatedText
    }

    // MARK: - MyMemory API (フォールバック)

    private func translateWithMyMemory(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // 特殊文字をエンコード
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(sourceLang)|\(targetLang)")
        ]

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.apiError
        }

        struct MyMemoryResponse: Codable {
            let responseData: ResponseData?
            struct ResponseData: Codable {
                let translatedText: String?
            }
        }

        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)

        guard let translatedText = decoded.responseData?.translatedText,
              !translatedText.isEmpty else {
            throw TranslationError.emptyResponse
        }

        return translatedText
    }
}

// MARK: - Error Types

enum TranslationError: LocalizedError {
    case invalidURL
    case apiError
    case emptyResponse
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURL"
        case .apiError: return "APIエラー"
        case .emptyResponse: return "翻訳結果が空"
        case .networkError: return "ネットワークエラー"
        }
    }
}
