//
//  SpeechRecognitionService.swift
//  douziapp
//
//  Apple Speech Frameworkを使用したリアルタイム音声認識
//

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechRecognitionService: ObservableObject {
    // MARK: - Published Properties

    @Published var recognizedText: String = ""
    @Published var isListening: Bool = false
    @Published var error: SpeechError?

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization

    init(locale: Locale = Locale(identifier: "en-US")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Public Methods

    /// 音声認識の権限をリクエスト
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// 音声認識を開始
    func startListening() throws {
        // 既存のタスクをキャンセル
        stopListening()

        // オーディオセッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // 認識タスクの開始
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }

                if let error = error {
                    self.error = .recognitionFailed(error.localizedDescription)
                    self.stopListening()
                }
            }
        }

        // オーディオ入力の設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    /// 音声認識を停止
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
    }

    /// 認識言語を変更
    func setLanguage(_ locale: Locale) {
        stopListening()
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    /// 認識テキストをクリア
    func clearText() {
        recognizedText = ""
    }
}

// MARK: - Error Types

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "音声認識が許可されていません"
        case .recognizerUnavailable:
            return "音声認識が利用できません"
        case .requestCreationFailed:
            return "認識リクエストの作成に失敗しました"
        case .recognitionFailed(let message):
            return "音声認識エラー: \(message)"
        }
    }
}
