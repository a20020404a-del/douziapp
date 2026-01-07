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
    @State private var isEnglishToJapanese = true // true: EN→JA, false: JA→EN

    var sourceLanguage: (code: String, name: String, flag: String) {
        isEnglishToJapanese ? ("en-US", "English", "🇺🇸") : ("ja-JP", "日本語", "🇯🇵")
    }

    var targetLanguage: (code: String, name: String, flag: String) {
        isEnglishToJapanese ? ("ja-JP", "日本語", "🇯🇵") : ("en-US", "English", "🇺🇸")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー（言語切り替えボタン付き）
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

                        // 原文表示エリア
                        SourceTextCard(
                            text: speechService.recognizedText,
                            language: sourceLanguage.name,
                            isActive: speechService.isListening
                        )

                        // 矢印アイコン
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        // 翻訳表示エリア
                        TranslatedTextCard(
                            text: translationService.translatedText,
                            language: targetLanguage.name,
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
                await translationService.translate(
                    text: newValue,
                    from: isEnglishToJapanese ? "en" : "ja",
                    to: isEnglishToJapanese ? "ja" : "en"
                )
            }
        }
        .onChange(of: translationService.translatedText) { _, newValue in
            guard !newValue.isEmpty, appSettings.autoSpeak else { return }
            ttsService.speak(text: newValue, language: targetLanguage.code)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            // 言語表示 + 切り替えボタン
            HStack(spacing: 16) {
                // ソース言語
                LanguageBadge(language: sourceLanguage.flag, flag: isEnglishToJapanese ? "EN" : "JA")

                // 切り替えボタン
                Button {
                    switchLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .symbolEffect(.bounce, value: isEnglishToJapanese)
                }
                .buttonStyle(.plain)

                // ターゲット言語
                LanguageBadge(language: targetLanguage.flag, flag: isEnglishToJapanese ? "JA" : "EN")
            }

            // ステータス表示
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

    private func switchLanguages() {
        // 録音中なら停止
        if speechService.isListening {
            speechService.stopListening()
        }

        // 言語切り替え
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isEnglishToJapanese.toggle()
        }

        // 音声認識の言語を変更
        speechService.setLanguage(sourceLanguage.code)

        // テキストをクリア
        speechService.clearText()
        translationService.clearTranslation()

        // 触覚フィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func toggleRecording() {
        if speechService.isListening {
            speechService.stopListening()
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    do {
                        // 現在の言語で認識開始
                        speechService.setLanguage(sourceLanguage.code)
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
