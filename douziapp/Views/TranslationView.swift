//
//  TranslationView.swift
//  douziapp
//
//  メイン翻訳画面 - 世界中の言語間での同時通訳UI
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
    @State private var showingSourceLanguagePicker = false
    @State private var showingTargetLanguagePicker = false
    @State private var sourceLanguage: Language = .english
    @State private var targetLanguage: Language = .japanese
    @State private var lastSavedSourceText: String = ""

    // 入力モード
    @State private var inputMode: InputMode = .voice
    @State private var textInput: String = ""
    @FocusState private var isTextFieldFocused: Bool

    enum InputMode: String, CaseIterable {
        case voice = "音声"
        case text = "テキスト"

        var icon: String {
            switch self {
            case .voice: return "mic.fill"
            case .text: return "keyboard"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ヘッダー（言語選択）
                headerView

                // 入力モード切り替え
                inputModeSelector

                ScrollView {
                    VStack(spacing: 20) {
                        // エラー表示
                        if !speechService.errorMessage.isEmpty {
                            ErrorBanner(message: speechService.errorMessage)
                        }
                        if !translationService.errorMessage.isEmpty {
                            ErrorBanner(message: translationService.errorMessage)
                        }

                        // 入力モードに応じた表示
                        if inputMode == .voice {
                            // 音声入力：原文表示エリア
                            SourceTextCard(
                                text: speechService.recognizedText,
                                language: sourceLanguage.name,
                                isActive: speechService.isListening
                            )
                        } else {
                            // テキスト入力
                            textInputView
                        }

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

                // 入力モードに応じたコントロール
                if inputMode == .voice {
                    recordingControlView
                } else {
                    textInputControlView
                }
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
            .sheet(isPresented: $showingSourceLanguagePicker) {
                LanguagePickerView(
                    selectedLanguage: $sourceLanguage,
                    title: "入力言語を選択",
                    excludeLanguage: targetLanguage
                ) {
                    onSourceLanguageChanged()
                }
            }
            .sheet(isPresented: $showingTargetLanguagePicker) {
                LanguagePickerView(
                    selectedLanguage: $targetLanguage,
                    title: "出力言語を選択",
                    excludeLanguage: sourceLanguage
                ) {
                    onTargetLanguageChanged()
                }
            }
        }
        .onChange(of: speechService.recognizedText) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await translationService.translate(
                    text: newValue,
                    from: sourceLanguage.id,
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

    private var inputModeSelector: some View {
        Picker("入力モード", selection: $inputMode) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onChange(of: inputMode) { _, newMode in
            // モード切り替え時にクリア
            if newMode == .voice {
                speechService.clearText()
            } else {
                textInput = ""
            }
            translationService.clearTranslation()

            // 音声入力中なら停止
            if speechService.isListening {
                speechService.stopListening()
            }
        }
    }

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Text(sourceLanguage.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if !textInput.isEmpty {
                    Button {
                        textInput = ""
                        translationService.clearTranslation()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // テキスト入力フィールド
            TextField("ここに入力...", text: $textInput, axis: .vertical)
                .font(.body)
                .lineLimit(5...10)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    translateTextInput()
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isTextFieldFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }

    private var textInputControlView: some View {
        VStack(spacing: 16) {
            // 翻訳ボタン
            Button {
                translateTextInput()
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("翻訳")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(textInput.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(textInput.isEmpty)
            .padding(.horizontal)

            // ステータステキスト
            Text(textInput.isEmpty ? "テキストを入力してください" : "翻訳ボタンをタップ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            // 言語表示 + 選択ボタン
            HStack(spacing: 12) {
                // ソース言語（タップで変更可能）
                Button {
                    showingSourceLanguagePicker = true
                } label: {
                    LanguageButton(language: sourceLanguage, label: "入力")
                }
                .buttonStyle(.plain)

                // 言語切り替えボタン
                Button {
                    swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                // ターゲット言語（タップで変更可能）
                Button {
                    showingTargetLanguagePicker = true
                } label: {
                    LanguageButton(language: targetLanguage, label: "出力")
                }
                .buttonStyle(.plain)
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

    /// テキスト入力を翻訳
    private func translateTextInput() {
        guard !textInput.isEmpty else { return }

        // キーボードを閉じる
        isTextFieldFocused = false

        Task {
            await translationService.translate(
                text: textInput,
                from: sourceLanguage.id,
                to: targetLanguage.id
            )

            // 自動読み上げ
            if appSettings.autoSpeak && !translationService.translatedText.isEmpty {
                ttsService.speak(text: translationService.translatedText, language: targetLanguage.speechCode)
            }

            // 履歴に保存
            saveTextInputToHistory()
        }
    }

    /// テキスト入力を履歴に保存
    private func saveTextInputToHistory() {
        let sourceText = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let translatedText = translationService.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sourceText.isEmpty,
              !translatedText.isEmpty,
              sourceText != lastSavedSourceText else {
            return
        }

        let record = TranslationRecord(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage.id,
            targetLanguage: targetLanguage.id
        )

        modelContext.insert(record)
        lastSavedSourceText = sourceText

        print("📝 履歴に保存: \(sourceText) → \(translatedText)")
    }

    private func swapLanguages() {
        // 録音中なら停止
        if speechService.isListening {
            speechService.stopListening()
        }

        // 言語を入れ替え
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
        }

        // 音声認識の言語を変更
        speechService.setLanguage(sourceLanguage.speechCode)

        // テキストをクリア
        speechService.clearText()
        translationService.clearTranslation()

        // 触覚フィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func onSourceLanguageChanged() {
        // 録音中なら停止
        if speechService.isListening {
            speechService.stopListening()
        }

        // 音声認識の言語を変更
        speechService.setLanguage(sourceLanguage.speechCode)

        // テキストをクリア
        speechService.clearText()
        translationService.clearTranslation()

        // 触覚フィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func onTargetLanguageChanged() {
        // テキストをクリア
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
                        speechService.setLanguage(sourceLanguage.speechCode)
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
            sourceLanguage: sourceLanguage.id,
            targetLanguage: targetLanguage.id
        )

        modelContext.insert(record)
        lastSavedSourceText = sourceText

        print("📝 履歴に保存: \(sourceText) → \(translatedText)")
    }
}

// MARK: - Language Button

struct LanguageButton: View {
    let language: Language
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(language.flag)
                .font(.largeTitle)
            Text(language.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Language Picker View

struct LanguagePickerView: View {
    @Binding var selectedLanguage: Language
    let title: String
    var excludeLanguage: Language? = nil
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var filteredLanguages: [Language] {
        var languages = Language.allLanguages

        // 除外する言語がある場合
        if let exclude = excludeLanguage {
            languages = languages.filter { $0.id != exclude.id }
        }

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
            ("よく使う", ["ja", "en", "zh", "ko"]),
            ("東アジア", ["ja", "zh", "zh-TW", "ko"]),
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
            .navigationTitle(title)
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
