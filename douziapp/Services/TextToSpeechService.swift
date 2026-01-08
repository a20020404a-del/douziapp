//
//  TextToSpeechService.swift
//  douziapp
//
//  高品質・自然な音声合成サービス
//  プレミアム音声を優先使用し、人間らしい読み上げを実現
//

import Foundation
import AVFoundation

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isSpeaking: Bool = false
    @Published var speechRate: Float = 0.5  // 0.0-1.0（デフォルト0.5 = 自然な速度）
    @Published var volume: Float = 1.0
    @Published var naturalness: Float = 1.0  // 自然さレベル（0.0-1.0）

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        cachePreferredVoices()
    }

    // MARK: - Public Methods

    /// テキストを自然に読み上げ
    func speak(text: String, language: String = "ja-JP") {
        guard !text.isEmpty else { return }

        // 既存の読み上げを停止
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // テキストを文単位で分割して自然なポーズを入れる
        let sentences = splitIntoSentences(text: text, language: language)

        for (index, sentence) in sentences.enumerated() {
            let utterance = createNaturalUtterance(
                text: sentence,
                language: language,
                isFirst: index == 0,
                isLast: index == sentences.count - 1
            )
            synthesizer.speak(utterance)
        }

        isSpeaking = true
    }

    /// 読み上げを停止
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// 読み上げを一時停止
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    /// 読み上げを再開
    func resume() {
        synthesizer.continueSpeaking()
    }

    // MARK: - Private Methods

    /// 自然な発話を作成
    private func createNaturalUtterance(text: String, language: String, isFirst: Bool, isLast: Bool) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        // 最適な音声を選択
        utterance.voice = getBestVoice(for: language)

        // 言語に応じた自然な速度を設定
        let baseRate = getOptimalRate(for: language)
        utterance.rate = baseRate

        // 音量
        utterance.volume = volume

        // ピッチ（声の高さ）- 少し変化をつけて自然に
        utterance.pitchMultiplier = getPitch(for: language)

        // 文の前後にポーズを追加して自然なリズムに
        if isFirst {
            utterance.preUtteranceDelay = 0.1  // 最初は少し間を置く
        } else {
            utterance.preUtteranceDelay = 0.3  // 文間のポーズ
        }

        if isLast {
            utterance.postUtteranceDelay = 0.2  // 最後は余韻を残す
        } else {
            utterance.postUtteranceDelay = 0.1
        }

        return utterance
    }

    /// 言語に最適な音声を取得（プレミアム音声を優先）
    private func getBestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        // キャッシュをチェック
        if let cached = voiceCache[language] {
            return cached
        }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        let languagePrefix = String(language.prefix(2))

        // 優先順位：
        // 1. 拡張音声（Enhanced/Premium）を最優先
        // 2. 完全一致する言語
        // 3. 言語プレフィックスが一致する音声

        // 拡張音声（高品質）を検索
        let enhancedVoices = voices.filter { voice in
            voice.language.hasPrefix(languagePrefix) &&
            (voice.quality == .enhanced || voice.identifier.contains("premium") || voice.identifier.contains("enhanced"))
        }

        if let enhanced = enhancedVoices.first {
            voiceCache[language] = enhanced
            print("🎤 高品質音声を使用: \(enhanced.name) (\(enhanced.language))")
            return enhanced
        }

        // 完全一致を検索
        if let exact = voices.first(where: { $0.language == language }) {
            voiceCache[language] = exact
            print("🎤 標準音声を使用: \(exact.name) (\(exact.language))")
            return exact
        }

        // プレフィックス一致を検索
        if let prefixMatch = voices.first(where: { $0.language.hasPrefix(languagePrefix) }) {
            voiceCache[language] = prefixMatch
            print("🎤 代替音声を使用: \(prefixMatch.name) (\(prefixMatch.language))")
            return prefixMatch
        }

        return AVSpeechSynthesisVoice(language: language)
    }

    /// 言語に最適な読み上げ速度を取得
    private func getOptimalRate(for language: String) -> Float {
        let languagePrefix = String(language.prefix(2))

        // 基本速度（ユーザー設定を考慮）
        let userRate = AVSpeechUtteranceMinimumSpeechRate +
            (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * speechRate

        // 言語ごとの調整係数
        let adjustment: Float
        switch languagePrefix {
        case "ja":
            adjustment = 0.85  // 日本語は少しゆっくり
        case "zh":
            adjustment = 0.80  // 中国語もゆっくりめ
        case "ko":
            adjustment = 0.85  // 韓国語
        case "ar", "he":
            adjustment = 0.80  // アラビア語、ヘブライ語
        case "th", "vi":
            adjustment = 0.85  // タイ語、ベトナム語（声調言語）
        case "de", "ru":
            adjustment = 0.90  // ドイツ語、ロシア語
        case "es", "it", "pt":
            adjustment = 0.95  // スペイン語、イタリア語、ポルトガル語（速めでもOK）
        case "en":
            adjustment = 0.90  // 英語
        case "fr":
            adjustment = 0.90  // フランス語
        default:
            adjustment = 0.90
        }

        return userRate * adjustment * naturalness
    }

    /// 言語に応じたピッチを取得
    private func getPitch(for language: String) -> Float {
        let languagePrefix = String(language.prefix(2))

        switch languagePrefix {
        case "ja":
            return 1.0  // 日本語は標準
        case "zh":
            return 1.05  // 中国語は少し高め
        case "ko":
            return 1.0
        case "en":
            return 1.0
        case "fr":
            return 1.02  // フランス語は少し高め
        case "de":
            return 0.98  // ドイツ語は少し低め
        case "it":
            return 1.03  // イタリア語は少し高め
        case "es":
            return 1.02
        default:
            return 1.0
        }
    }

    /// テキストを文単位で分割
    private func splitIntoSentences(text: String, language: String) -> [String] {
        let languagePrefix = String(language.prefix(2))

        // 言語に応じた区切り文字
        let delimiters: CharacterSet
        switch languagePrefix {
        case "ja", "zh":
            // 日本語・中国語：句点、読点、感嘆符、疑問符
            delimiters = CharacterSet(charactersIn: "。！？!?．、，")
        case "ar", "fa", "he":
            // アラビア語、ペルシャ語、ヘブライ語
            delimiters = CharacterSet(charactersIn: ".!?،؟")
        default:
            // 欧米言語
            delimiters = CharacterSet(charactersIn: ".!?;")
        }

        // 分割
        var sentences: [String] = []
        var currentSentence = ""

        for char in text {
            currentSentence.append(char)
            if delimiters.contains(char.unicodeScalars.first!) {
                let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                currentSentence = ""
            }
        }

        // 残りのテキスト
        let remaining = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }

        // 文がない場合は元のテキストをそのまま
        if sentences.isEmpty {
            sentences = [text]
        }

        return sentences
    }

    /// プレミアム音声をキャッシュ
    private func cachePreferredVoices() {
        let preferredLanguages = ["ja-JP", "en-US", "zh-CN", "ko-KR", "fr-FR", "de-DE", "es-ES"]
        for lang in preferredLanguages {
            _ = getBestVoice(for: lang)
        }
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    /// 利用可能な高品質音声一覧を取得
    func getAvailableVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        let languagePrefix = String(language.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(languagePrefix) }
            .sorted { v1, v2 in
                // 高品質音声を上に
                if v1.quality == .enhanced && v2.quality != .enhanced { return true }
                if v1.quality != .enhanced && v2.quality == .enhanced { return false }
                return v1.name < v2.name
            }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // すべての発話が終了したかチェック
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
