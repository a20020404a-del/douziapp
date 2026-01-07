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
    @Published var errorMessage: String = ""
    @Published var authorizationStatus: String = "未確認"

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    // MARK: - Initialization

    private var currentLocale: String = "en-US"

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        audioEngine = AVAudioEngine()
    }

    /// 認識言語を変更
    func setLanguage(_ localeIdentifier: String) {
        currentLocale = localeIdentifier
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        print("🌐 音声認識言語を変更: \(localeIdentifier)")
    }

    // MARK: - Public Methods

    /// マイクと音声認識の権限を両方リクエスト
    func requestAuthorization() async -> Bool {
        // 1. マイク権限をリクエスト
        let micGranted = await requestMicrophonePermission()
        if !micGranted {
            errorMessage = "マイクの権限が必要です"
            authorizationStatus = "マイク拒否"
            return false
        }

        // 2. 音声認識権限をリクエスト
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

    /// 音声認識を開始
    func startListening() throws {
        // リセット
        stopListening()
        errorMessage = ""
        recognizedText = ""

        // 新しいAudioEngineを作成
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw SpeechError.audioEngineError
        }

        // オーディオセッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "オーディオセッションエラー: \(error.localizedDescription)"
            throw SpeechError.audioSessionError
        }

        // 認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // 認識タスクの開始
        guard let speechRecognizer = speechRecognizer else {
            errorMessage = "音声認識が初期化されていません"
            throw SpeechError.recognizerUnavailable
        }

        if !speechRecognizer.isAvailable {
            errorMessage = "音声認識が利用できません"
            throw SpeechError.recognizerUnavailable
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    print("認識結果: \(self.recognizedText)")
                }

                if let error = error {
                    // 認識が終了した場合のエラーは無視
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        // 音声入力がなかった場合 - 正常
                        return
                    }
                    self.errorMessage = "認識エラー: \(error.localizedDescription)"
                    print("認識エラー: \(error)")
                }
            }
        }

        // オーディオ入力の設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // フォーマットが有効か確認
        guard recordingFormat.sampleRate > 0 else {
            errorMessage = "無効なオーディオフォーマット"
            throw SpeechError.audioEngineError
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            print("音声認識開始")
        } catch {
            errorMessage = "オーディオエンジン起動エラー: \(error.localizedDescription)"
            throw SpeechError.audioEngineError
        }
    }

    /// 音声認識を停止
    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        print("音声認識停止")
    }

    /// 認識テキストをクリア
    func clearText() {
        recognizedText = ""
        errorMessage = ""
    }
}

// MARK: - Error Types

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case audioSessionError
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "音声認識が許可されていません"
        case .recognizerUnavailable:
            return "音声認識が利用できません"
        case .requestCreationFailed:
            return "認識リクエストの作成に失敗しました"
        case .audioSessionError:
            return "オーディオセッションエラー"
        case .audioEngineError:
            return "オーディオエンジンエラー"
        }
    }
}
