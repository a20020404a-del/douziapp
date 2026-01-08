//
//  TranslationView.swift
//  douziapp
//
//  メイン翻訳画面 - 世界中の言語から日本語への同時通訳UI
//

import SwiftUI
import SwiftData

struct TranslationView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var translationService = TranslationService()
    @StateObject private var ttsService = TextToSpeechService()
    @EnvironmentObject var appSettings: AppSettings

    @State private var showingPermissionAlert = false
    @State private var showingLanguagePicker = false
    @State private var selectedLanguage: Language = .english
    @State private var lastSavedSourceText: String = ""

    // ターゲットは常に日本語
    private let targetLanguage: Language = .japanese

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー（言語選択）
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
                            language: selectedLanguage.name,
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
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView(selectedLanguage: $selectedLanguage) {
                    onLanguageChanged()
                }
            }
        }
        .onChange(of: speechService.recognizedText) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await translationService.translate(
                    text: newValue,
                    from: selectedLanguage.id,
                    to: targetLanguage.id
                )
            }
        }
        .onChange(of: translationService.translatedText) { _, newValue in
            guard !newValue.isEmpty, appSettings.autoSpeak else { return }
            ttsService.speak(text: newValue, language: targetLanguage.speechCode)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            // 言語表示 + 選択ボタン
            HStack(spacing: 16) {
                // ソース言語（タップで変更可能）
                Button {
                    showingLanguagePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedLanguage.flag)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedLanguage.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("タップで変更")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // 矢印
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundStyle(.blue)

                // ターゲット言語（日本語固定）
                HStack(spacing: 8) {
                    Text(targetLanguage.flag)
                        .font(.title)
                    Text(targetLanguage.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
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

    private func onLanguageChanged() {
        // 録音中なら停止
        if speechService.isListening {
            speechService.stopListening()
        }

        // 音声認識の言語を変更
        speechService.setLanguage(selectedLanguage.speechCode)

        // テキストをクリア
        speechService.clearText()
        translationService.clearTranslation()

        // 触覚フィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func toggleRecording() {
        if speechService.isListening {
            // 録音停止時に履歴を保存
            saveToHistory()
            speechService.stopListening()
        } else {
            Task {
                let authorized = await speechService.requestAuthorization()
                if authorized {
                    do {
                        // 現在の言語で認識開始
                        speechService.setLanguage(selectedLanguage.speechCode)
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

    /// 翻訳結果を履歴に保存
    private func saveToHistory() {
        let sourceText = speechService.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translatedText = translationService.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空でない、かつ前回と異なる場合のみ保存
        guard !sourceText.isEmpty,
              !translatedText.isEmpty,
              sourceText != lastSavedSourceText else {
            return
        }

        let record = TranslationRecord(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: selectedLanguage.id,
            targetLanguage: targetLanguage.id
        )

        modelContext.insert(record)
        lastSavedSourceText = sourceText

        print("📝 履歴に保存: \(sourceText) → \(translatedText)")
    }
}

// MARK: - Language Picker View

struct LanguagePickerView: View {
    @Binding var selectedLanguage: Language
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var filteredLanguages: [Language] {
        let languages = Language.sourceLanguages
        if searchText.isEmpty {
            return languages
        }
        return languages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.localName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // 地域でグループ化
    var groupedLanguages: [(String, [Language])] {
        let groups: [(String, [String])] = [
            ("よく使う", ["en", "zh", "ko"]),
            ("東アジア", ["zh", "zh-TW", "ko"]),
            ("東南アジア", ["th", "vi", "id", "ms", "tl"]),
            ("南アジア", ["hi", "bn", "ta"]),
            ("中東", ["ar", "fa", "he", "tr"]),
            ("ヨーロッパ（西）", ["en", "en-GB", "fr", "de", "es", "pt", "pt-BR", "it", "nl"]),
            ("ヨーロッパ（北）", ["sv", "no", "da", "fi"]),
            ("ヨーロッパ（東）", ["ru", "pl", "uk", "cs", "hu", "ro", "el"]),
            ("アフリカ", ["sw", "af"])
        ]

        if !searchText.isEmpty {
            return [("検索結果", filteredLanguages)]
        }

        return groups.compactMap { (name, ids) in
            let languages = ids.compactMap { id in
                filteredLanguages.first { $0.id == id }
            }
            return languages.isEmpty ? nil : (name, languages)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedLanguages, id: \.0) { group, languages in
                    Section(group) {
                        ForEach(languages) { language in
                            Button {
                                selectedLanguage = language
                                onSelect()
                                dismiss()
                            } label: {
                                HStack {
                                    Text(language.flag)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(language.name)
                                            .foregroundStyle(.primary)
                                        Text(language.localName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if language.id == selectedLanguage.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("入力言語を選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "言語を検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
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
