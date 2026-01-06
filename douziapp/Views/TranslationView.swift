//
//  TranslationView.swift
//  douziapp
//
//  メイン翻訳画面 - リアルタイム同時通訳UI
//

import SwiftUI

struct TranslationView: View {
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var translationService = TranslationService()
    @StateObject private var ttsService = TextToSpeechService()
    @EnvironmentObject var appSettings: AppSettings

    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        // エラー表示
                        if !speechService.errorMessage.isEmpty {
                            ErrorBanner(message: speechService.errorMessage)
                        }
                        if !translationService.errorMessage.isEmpty {
                            ErrorBanner(message: translationService.errorMessage)
                        }

                        // 英語（原文）表示エリア
                        SourceTextCard(
                            text: speechService.recognizedText,
                            language: "English",
                            isActive: speechService.isListening
                        )

                        // 矢印アイコン
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        // 日本語（翻訳）表示エリア
                        TranslatedTextCard(
                            text: translationService.translatedText,
                            language: "日本語",
                            isLoading: translationService.isTranslating
                        )
                    }
                    .padding()
                }

                Spacer()

                // 録音コントロール
                recordingControlView
            }
            .navigationTitle("同時通訳")
            .navigationBarTitleDisplayMode(.inline)
            .alert("マイクへのアクセスが必要です", isPresented: $showingPermissionAlert) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("音声認識を使用するには、設定でマイクへのアクセスを許可してください。")
            }
        }
        .onChange(of: speechService.recognizedText) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await translationService.translate(text: newValue)
            }
        }
        .onChange(of: translationService.translatedText) { _, newValue in
            guard !newValue.isEmpty, appSettings.autoSpeak else { return }
            ttsService.speak(text: newValue)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                LanguageBadge(language: "EN", flag: "🇺🇸")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                LanguageBadge(language: "JA", flag: "🇯🇵")
            }

            // 認証ステータス表示
            Text("ステータス: \(speechService.authorizationStatus)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var recordingControlView: some View {
        VStack(spacing: 16) {
            // 録音ボタン
            RecordButton(isRecording: $speechService.isListening) {
                toggleRecording()
            }

            // ステータステキスト
            Text(speechService.isListening ? "🎤 認識中... タップして停止" : "タップして開始")
                .font(.subheadline)
                .foregroundStyle(speechService.isListening ? .red : .secondary)
        }
        .padding(.vertical, 24)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func toggleRecording() {
        if speechService.isListening {
            speechService.stopListening()
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    do {
                        try speechService.startListening()
                    } catch {
                        print("録音開始エラー: \(error)")
                    }
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    TranslationView()
        .environmentObject(AppSettings())
}
