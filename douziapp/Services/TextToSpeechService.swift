//
//  TextToSpeechService.swift
//  douziapp
//
//  AVSpeechSynthesizerを使用した音声合成サービス
//

import Foundation
import AVFoundation

@MainActor
class TextToSpeechService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isSpeaking: Bool = false
    @Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var volume: Float = 1.0

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingUtterances: [AVSpeechUtterance] = []

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Public Methods

    /// テキストを読み上げ
    func speak(text: String, language: String = "ja-JP") {
        guard !text.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = speechRate
        utterance.volume = volume
        utterance.pitchMultiplier = 1.0

        // 日本語の場合は少しゆっくりめに
        if language.hasPrefix("ja") {
            utterance.rate = min(speechRate, AVSpeechUtteranceDefaultSpeechRate * 0.9)
        }

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// 読み上げを停止
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingUtterances.removeAll()
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

    /// 利用可能な日本語音声を取得
    func availableJapaneseVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ja") }
    }

    /// 読み上げ速度を設定（0.0-1.0）
    func setRate(_ rate: Float) {
        speechRate = AVSpeechUtteranceMinimumSpeechRate +
            (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * rate
    }

    // MARK: - Private Methods

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
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
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
