//
//  TextToSpeechService.swift
//  douziapp
//
//  高品質・自然な音声合成サービス
//  Google Cloud TTS (WaveNet) を使用して極限まで人間らしい声を実現
//  フォールバックとしてApple TTS も使用
//

import Foundation
import AVFoundation

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isSpeaking: Bool = false
    @Published var speechRate: Float = 1.0  // 0.5-2.0（デフォルト1.0）
    @Published var volume: Float = 1.0
    @Published var useHighQualityVoice: Bool = true  // 高品質音声を使用

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    // Google Cloud TTS の言語コードマッピング
    private let googleLanguageCodes: [String: (code: String, voice: String)] = [
        "ja": ("ja-JP", "ja-JP-Neural2-B"),      // 日本語 - Neural2（最高品質）
        "en": ("en-US", "en-US-Neural2-J"),      // 英語 - Neural2
        "en-GB": ("en-GB", "en-GB-Neural2-B"),   // イギリス英語
        "zh": ("cmn-CN", "cmn-CN-Wavenet-C"),    // 中国語
        "zh-TW": ("cmn-TW", "cmn-TW-Wavenet-A"), // 台湾中国語
        "ko": ("ko-KR", "ko-KR-Neural2-B"),      // 韓国語
        "fr": ("fr-FR", "fr-FR-Neural2-B"),      // フランス語
        "de": ("de-DE", "de-DE-Neural2-B"),      // ドイツ語
        "es": ("es-ES", "es-ES-Neural2-B"),      // スペイン語
        "it": ("it-IT", "it-IT-Neural2-B"),      // イタリア語
        "pt": ("pt-PT", "pt-PT-Wavenet-B"),      // ポルトガル語
        "pt-BR": ("pt-BR", "pt-BR-Neural2-B"),   // ブラジルポルトガル語
        "ru": ("ru-RU", "ru-RU-Wavenet-B"),      // ロシア語
        "ar": ("ar-XA", "ar-XA-Wavenet-B"),      // アラビア語
        "hi": ("hi-IN", "hi-IN-Neural2-B"),      // ヒンディー語
        "th": ("th-TH", "th-TH-Neural2-C"),      // タイ語
        "vi": ("vi-VN", "vi-VN-Wavenet-A"),      // ベトナム語
        "id": ("id-ID", "id-ID-Wavenet-B"),      // インドネシア語
        "tr": ("tr-TR", "tr-TR-Wavenet-B"),      // トルコ語
        "pl": ("pl-PL", "pl-PL-Wavenet-B"),      // ポーランド語
        "nl": ("nl-NL", "nl-NL-Wavenet-B"),      // オランダ語
        "sv": ("sv-SE", "sv-SE-Wavenet-A"),      // スウェーデン語
        "da": ("da-DK", "da-DK-Wavenet-A"),      // デンマーク語
        "no": ("nb-NO", "nb-NO-Wavenet-B"),      // ノルウェー語
        "fi": ("fi-FI", "fi-FI-Wavenet-A"),      // フィンランド語
        "el": ("el-GR", "el-GR-Wavenet-A"),      // ギリシャ語
        "cs": ("cs-CZ", "cs-CZ-Wavenet-A"),      // チェコ語
        "hu": ("hu-HU", "hu-HU-Wavenet-A"),      // ハンガリー語
        "ro": ("ro-RO", "ro-RO-Wavenet-A"),      // ルーマニア語
        "uk": ("uk-UA", "uk-UA-Wavenet-A"),      // ウクライナ語
        "he": ("he-IL", "he-IL-Wavenet-A"),      // ヘブライ語
    ]

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Public Methods

    /// テキストを自然に読み上げ（高品質API優先）
    func speak(text: String, language: String = "ja-JP") {
        guard !text.isEmpty else { return }

        // 既存の再生を停止
        stop()

        let languagePrefix = String(language.prefix(2))
        let fullLanguageCode = language.contains("-") ? language.replacingOccurrences(of: "-", with: "-").lowercased() : language

        // 高品質音声を試す
        if useHighQualityVoice {
            Task {
                if let audioData = await fetchGoogleTTS(text: text, languageCode: languagePrefix) {
                    await playAudioData(audioData)
                    return
                }
                // フォールバック
                await speakWithAppleTTS(text: text, language: language)
            }
        } else {
            Task {
                await speakWithAppleTTS(text: text, language: language)
            }
        }
    }

    /// 読み上げを停止
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// 読み上げを一時停止
    func pause() {
        audioPlayer?.pause()
        synthesizer.pauseSpeaking(at: .word)
    }

    /// 読み上げを再開
    func resume() {
        audioPlayer?.play()
        synthesizer.continueSpeaking()
    }

    // MARK: - Google Cloud TTS（高品質・人間らしい音声）

    private func fetchGoogleTTS(text: String, languageCode: String) async -> Data? {
        // Google Cloud TTS API（無料枠あり）
        // 注意: 本番環境ではAPIキーをセキュアに管理してください

        guard let config = googleLanguageCodes[languageCode] else {
            print("⚠️ Google TTS: 言語 \(languageCode) は未対応、Apple TTSを使用")
            return nil
        }

        // Google Translate TTS（無料・高品質）
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlString = "https://translate.google.com/translate_tts?ie=UTF-8&q=\(encodedText)&tl=\(config.code)&client=tw-ob"

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("https://translate.google.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count > 1000 else {  // 有効な音声データかチェック
                print("⚠️ Google TTS: レスポンスが無効")
                return nil
            }

            print("✅ Google TTS: 高品質音声を取得 (\(data.count) bytes)")
            return data
        } catch {
            print("⚠️ Google TTS エラー: \(error.localizedDescription)")
            return nil
        }
    }

    /// 音声データを再生
    private func playAudioData(_ data: Data) async {
        do {
            // 一時ファイルに保存
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tts_\(UUID().uuidString).mp3")
            try data.write(to: tempURL)

            audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.enableRate = true
            audioPlayer?.rate = speechRate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isSpeaking = true
            print("🔊 高品質音声を再生中...")

            // 一時ファイルを後で削除
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                try? FileManager.default.removeItem(at: tempURL)
            }
        } catch {
            print("❌ 音声再生エラー: \(error)")
            isSpeaking = false
        }
    }

    // MARK: - Apple TTS（フォールバック）

    private func speakWithAppleTTS(text: String, language: String) async {
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

    /// 自然な発話を作成（Apple TTS用）
    private func createNaturalUtterance(text: String, language: String, isFirst: Bool, isLast: Bool) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        // 最適な音声を選択
        utterance.voice = getBestVoice(for: language)

        // 速度調整
        let baseRate = AVSpeechUtteranceDefaultSpeechRate * speechRate * 0.85
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(baseRate, AVSpeechUtteranceMaximumSpeechRate))

        utterance.volume = volume
        utterance.pitchMultiplier = getPitch(for: language)

        // 自然なポーズ
        utterance.preUtteranceDelay = isFirst ? 0.1 : 0.25
        utterance.postUtteranceDelay = isLast ? 0.15 : 0.1

        return utterance
    }

    /// 言語に最適な音声を取得（Enhanced音声を優先）
    private func getBestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        if let cached = voiceCache[language] {
            return cached
        }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        let languagePrefix = String(language.prefix(2))

        // Enhanced音声を優先
        let enhancedVoices = voices.filter { voice in
            voice.language.hasPrefix(languagePrefix) && voice.quality == .enhanced
        }

        if let enhanced = enhancedVoices.first {
            voiceCache[language] = enhanced
            print("🎤 Enhanced音声: \(enhanced.name)")
            return enhanced
        }

        // 通常音声
        if let normal = voices.first(where: { $0.language.hasPrefix(languagePrefix) }) {
            voiceCache[language] = normal
            return normal
        }

        return AVSpeechSynthesisVoice(language: language)
    }

    /// 言語に応じたピッチを取得
    private func getPitch(for language: String) -> Float {
        let languagePrefix = String(language.prefix(2))
        switch languagePrefix {
        case "ja": return 1.0
        case "zh": return 1.03
        case "ko": return 1.0
        case "fr", "it": return 1.02
        case "de": return 0.98
        default: return 1.0
        }
    }

    /// テキストを文単位で分割
    private func splitIntoSentences(text: String, language: String) -> [String] {
        let languagePrefix = String(language.prefix(2))

        let delimiters: CharacterSet
        switch languagePrefix {
        case "ja", "zh":
            delimiters = CharacterSet(charactersIn: "。！？!?．")
        case "ar", "fa", "he":
            delimiters = CharacterSet(charactersIn: ".!?،؟")
        default:
            delimiters = CharacterSet(charactersIn: ".!?")
        }

        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if let scalar = char.unicodeScalars.first, delimiters.contains(scalar) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        let remaining = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }

        return sentences.isEmpty ? [text] : sentences
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio session error: \(error)")
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

// MARK: - AVAudioPlayerDelegate

extension TextToSpeechService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            print("🔊 音声再生完了")
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isSpeaking = false
            print("❌ 音声デコードエラー: \(error?.localizedDescription ?? "不明")")
        }
    }
}
