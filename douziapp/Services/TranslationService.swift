//
//  TranslationService.swift
//  douziapp
//
//  翻訳API連携サービス - MyMemory API（無料）を使用
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
    private let debounceDelay: TimeInterval = 0.3

    // キャッシュ（同じテキストの再翻訳を防ぐ）
    private var translationCache: [String: String] = [:]

    // MARK: - Public Methods

    /// テキストを翻訳（英語→日本語）
    func translate(text: String) async {
        // 空文字はスキップ
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // 同一テキストはスキップ
        guard text != lastSourceText else { return }

        // キャッシュをチェック
        if let cached = translationCache[text] {
            translatedText = cached
            lastSourceText = text
            return
        }

        // 既存のタスクをキャンセル（デバウンス）
        translateTask?.cancel()

        translateTask = Task {
            // デバウンス待機
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            isTranslating = true
            errorMessage = ""

            do {
                // MyMemory API を使用
                let result = try await translateWithMyMemory(text: text, from: "en", to: "ja")

                if !Task.isCancelled {
                    translatedText = result
                    lastSourceText = text
                    translationCache[text] = result
                    print("翻訳成功: \(text) → \(result)")
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = "翻訳エラー: \(error.localizedDescription)"
                    print("翻訳エラー: \(error)")
                    // フォールバック翻訳を使用
                    translatedText = "【翻訳中】\(text)"
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

    // MARK: - MyMemory API (無料・APIキー不要)

    private func translateWithMyMemory(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // URLエンコード
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw TranslationError.invalidInput
        }

        // MyMemory API URL
        let urlString = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=\(sourceLang)|\(targetLang)"

        guard let url = URL(string: urlString) else {
            throw TranslationError.invalidURL
        }

        // APIリクエスト
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslationError.apiError(statusCode: httpResponse.statusCode)
        }

        // JSONパース
        let myMemoryResponse = try JSONDecoder().decode(MyMemoryResponse.self, from: data)

        // 翻訳結果を取得
        guard let translatedText = myMemoryResponse.responseData?.translatedText,
              !translatedText.isEmpty else {
            throw TranslationError.emptyResponse
        }

        return translatedText
    }
}

// MARK: - MyMemory API Response Models

struct MyMemoryResponse: Codable {
    let responseData: ResponseData?
    let responseStatus: Int?
    let responseDetails: String?

    struct ResponseData: Codable {
        let translatedText: String?
        let match: Double?
    }
}

// MARK: - Error Types

enum TranslationError: LocalizedError {
    case invalidInput
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case emptyResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "無効な入力テキスト"
        case .invalidURL:
            return "無効なURL"
        case .invalidResponse:
            return "無効なレスポンス"
        case .apiError(let statusCode):
            return "APIエラー (コード: \(statusCode))"
        case .emptyResponse:
            return "翻訳結果が空です"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        }
    }
}
