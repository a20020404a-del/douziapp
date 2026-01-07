//
//  TranslationService.swift
//  douziapp
//
//  高精度翻訳サービス - 複数APIを使用して最高の翻訳品質を実現
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
    private var currentSourceLang: String = "en"
    private var currentTargetLang: String = "ja"

    // キャッシュ
    private var translationCache: [String: String] = [:]

    // MARK: - Public Methods

    /// 高精度翻訳（双方向対応）
    func translate(text: String, from sourceLang: String = "en", to targetLang: String = "ja") async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else { return }
        guard trimmedText.count >= 2 else { return }

        // 言語が変わったらキャッシュをクリア
        if sourceLang != currentSourceLang || targetLang != currentTargetLang {
            translationCache.removeAll()
            currentSourceLang = sourceLang
            currentTargetLang = targetLang
        }

        guard trimmedText != lastSourceText else { return }

        // キャッシュチェック
        let cacheKey = "\(sourceLang)|\(targetLang)|\(trimmedText)"
        if let cached = translationCache[cacheKey] {
            translatedText = cached
            lastSourceText = trimmedText
            return
        }

        translateTask?.cancel()

        translateTask = Task {
            // 短いデバウンス（高速応答）
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
            guard !Task.isCancelled else { return }

            isTranslating = true
            errorMessage = ""

            // 複数のAPIを順番に試す（精度順）
            let result = await tryTranslateWithMultipleAPIs(
                text: trimmedText,
                from: sourceLang,
                to: targetLang
            )

            if !Task.isCancelled {
                if let translation = result {
                    translatedText = translation
                    lastSourceText = trimmedText
                    translationCache[cacheKey] = translation
                    print("✅ 翻訳成功 (\(sourceLang)→\(targetLang)): \(trimmedText) → \(translation)")
                } else {
                    errorMessage = "翻訳に失敗しました"
                    translatedText = "翻訳できませんでした"
                }
            }

            isTranslating = false
        }
    }

    func clearTranslation() {
        translatedText = ""
        lastSourceText = ""
        errorMessage = ""
    }

    // MARK: - 複数API翻訳（精度優先）

    private func tryTranslateWithMultipleAPIs(text: String, from: String, to: String) async -> String? {
        // 1. Google Translate（最高精度）
        if let result = try? await translateWithGoogleTranslate(text: text, from: from, to: to) {
            print("📗 Google Translate使用")
            return result
        }

        // 2. MyMemory API（フォールバック）
        if let result = try? await translateWithMyMemory(text: text, from: from, to: to) {
            print("📘 MyMemory API使用")
            return result
        }

        // 3. LibreTranslate（最終フォールバック）
        if let result = try? await translateWithLibreTranslate(text: text, from: from, to: to) {
            print("📙 LibreTranslate使用")
            return result
        }

        return nil
    }

    // MARK: - Google Translate（非公式API - 高精度）

    private func translateWithGoogleTranslate(text: String, from: String, to: String) async throws -> String {
        // Google Translate 非公式API（無料・高精度）
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: from),
            URLQueryItem(name: "tl", value: to),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.apiError
        }

        // Google Translateのレスポンスをパース
        // 形式: [[["翻訳結果","原文",null,null,10]],null,"en",...]
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let firstArray = json.first as? [Any] else {
            throw TranslationError.invalidResponse
        }

        var translatedParts: [String] = []
        for item in firstArray {
            if let itemArray = item as? [Any],
               let translatedPart = itemArray.first as? String {
                translatedParts.append(translatedPart)
            }
        }

        let result = translatedParts.joined()
        guard !result.isEmpty else {
            throw TranslationError.emptyResponse
        }

        return result
    }

    // MARK: - MyMemory API

    private func translateWithMyMemory(text: String, from: String, to: String) async throws -> String {
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(from)|\(to)")
        ]

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

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
              !translatedText.isEmpty,
              !translatedText.uppercased().contains("MYMEMORY WARNING") else {
            throw TranslationError.emptyResponse
        }

        return translatedText
    }

    // MARK: - LibreTranslate API

    private func translateWithLibreTranslate(text: String, from: String, to: String) async throws -> String {
        let url = URL(string: "https://libretranslate.com/translate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "q": text,
            "source": from,
            "target": to,
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
}

// MARK: - Errors

enum TranslationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError
    case emptyResponse
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURL"
        case .invalidResponse: return "無効なレスポンス"
        case .apiError: return "APIエラー"
        case .emptyResponse: return "翻訳結果が空"
        case .networkError: return "ネットワークエラー"
        }
    }
}
