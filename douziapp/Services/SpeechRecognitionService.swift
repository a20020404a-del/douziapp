//
//  SpeechRecognitionService.swift
//  douziapp
//
//  高精度リアルタイム音声認識サービス
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionService: ObservableObject {
    // MARK: - Published Properties

    @Published var recognizedText: String = ""
    @Published var isListening: Bool = false
    @Published var errorMessage: String = ""
    @Published var authorizationStatus: String = "未確認"
    @Published var confidenceLevel: Float = 0.0

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var currentLocale: String = "en-US"

    // MARK: - Initialization

    init() {
        setupRecognizer(locale: "en-US")
    }

    private func setupRecognizer(locale: String) {
        currentLocale = locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        speechRecognizer?.defaultTaskHint = .dictation
        audioEngine = AVAudioEngine()
    }

    /// 認識言語を変更
    func setLanguage(_ localeIdentifier: String) {
        setupRecognizer(locale: localeIdentifier)
        print("🌐 音声認識言語を変更: \(localeIdentifier)")
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        // マイク権限
        let micGranted = await requestMicrophonePermission()
        if !micGranted {
            errorMessage = "マイクの権限が必要です"
            authorizationStatus = "マイク拒否"
            return false
        }

        // 音声認識権限
        let speechGranted = await requestSpeechPermission()
        if !speechGranted {
            errorMessage = "音声認識の権限が必要です"
            authorizationStatus = "音声認識拒否"
            return false
        }

        authorizationStatus = "許可済み"
        return true
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - 高精度音声認識

    func startListening() throws {
        stopListening()
        errorMessage = ""
        recognizedText = ""
        confidenceLevel = 0.0

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw SpeechError.audioEngineError
        }

        // 高品質オーディオセッション設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // 高精度認識のための設定
            try audioSession.setCategory(.playAndRecord,
                                         mode: .measurement,
                                         options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setPreferredSampleRate(44100.0)  // 高サンプルレート
            try audioSession.setPreferredIOBufferDuration(0.005)  // 低レイテンシ
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "オーディオセッションエラー"
            throw SpeechError.audioSessionError
        }

        // 高精度認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        // 精度を最大化する設定
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true  // 句読点を追加

        // オンデバイス認識が利用可能なら使用（より高速・高精度）
        if #available(iOS 13, *) {
            if speechRecognizer?.supportsOnDeviceRecognition == true {
                recognitionRequest.requiresOnDeviceRecognition = false // クラウドの方が精度が高い
            }
        }

        // コンテキストヒントを追加（認識精度向上）
        if currentLocale.hasPrefix("en") {
            recognitionRequest.contextualStrings = [
                "hello", "thank you", "please", "excuse me",
                "how are you", "nice to meet you", "goodbye",
                "where is", "what time", "how much"
            ]
        } else if currentLocale.hasPrefix("ja") {
            recognitionRequest.contextualStrings = [
                "こんにちは", "ありがとう", "お願いします", "すみません",
                "お元気ですか", "はじめまして", "さようなら",
                "どこですか", "何時ですか", "いくらですか"
            ]
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "音声認識が利用できません"
            throw SpeechError.recognizerUnavailable
        }

        // 認識タスクの開始
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    // 最も信頼度の高い結果を使用
                    let bestTranscription = result.bestTranscription
                    self.recognizedText = bestTranscription.formattedString

                    // 信頼度を計算
                    if let segment = bestTranscription.segments.last {
                        self.confidenceLevel = segment.confidence
                    }

                    print("🎤 認識結果: \(self.recognizedText) (信頼度: \(self.confidenceLevel))")
                }

                if let error = error {
                    self.handleRecognitionError(error)
                }
            }
        }

        // 高品質オーディオ入力設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            errorMessage = "無効なオーディオフォーマット"
            throw SpeechError.audioEngineError
        }

        // 大きめのバッファで安定した認識
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            print("🎙️ 高精度音声認識開始 (\(currentLocale))")
        } catch {
            errorMessage = "オーディオエンジン起動エラー"
            throw SpeechError.audioEngineError
        }
    }

    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError

        // 正常終了コードは無視（エラーメッセージを表示しない）
        let normalCodes = [203, 209, 216, 301, 1110, 1700]
        if nsError.domain == "kAFAssistantErrorDomain" && normalCodes.contains(nsError.code) {
            print("📍 セッション終了 (コード: \(nsError.code))")
            // 正常終了時はエラーメッセージをクリア
            errorMessage = ""
            return
        }

        errorMessage = "認識エラー"
        print("❌ 認識エラー: \(error)")

        // 3秒後にエラーメッセージを自動クリア
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if self.errorMessage == "認識エラー" {
                    self.errorMessage = ""
                }
            }
        }
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        errorMessage = "" // 停止時にエラーメッセージをクリア
        print("⏹️ 音声認識停止")
    }

    func clearText() {
        recognizedText = ""
        errorMessage = ""
        confidenceLevel = 0.0
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized, recognizerUnavailable, requestCreationFailed
    case audioSessionError, audioEngineError

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "音声認識が許可されていません"
        case .recognizerUnavailable: return "音声認識が利用できません"
        case .requestCreationFailed: return "認識リクエストの作成に失敗"
        case .audioSessionError: return "オーディオセッションエラー"
        case .audioEngineError: return "オーディオエンジンエラー"
        }
    }
}
