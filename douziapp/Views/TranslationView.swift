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

    @State private var isRecording = false
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        // 英語（原文）表示エリア
                        SourceTextCard(
                            text: speechService.recognizedText,
                            language: "English",
                            isActive: isRecording
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
        HStack {
            LanguageBadge(language: "EN", flag: "🇺🇸")
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            LanguageBadge(language: "JA", flag: "🇯🇵")
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var recordingControlView: some View {
        VStack(spacing: 16) {
            // 録音ボタン
            RecordButton(isRecording: $isRecording) {
                toggleRecording()
            }

            // ステータステキスト
            Text(isRecording ? "タップして停止" : "タップして開始")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            speechService.stopListening()
            isRecording = false
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    try? speechService.startListening()
                    isRecording = true
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }
}

#Preview {
    TranslationView()
        .environmentObject(AppSettings())
}
