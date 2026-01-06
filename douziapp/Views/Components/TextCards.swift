//
//  TextCards.swift
//  douziapp
//
//  テキスト表示カードコンポーネント
//

import SwiftUI

// MARK: - Source Text Card (英語/原文)

struct SourceTextCard: View {
    let text: String
    let language: String
    var isActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Text(language)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("認識中")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            // テキスト表示
            Text(text.isEmpty ? "音声を待っています..." : text)
                .font(.body)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - Translated Text Card (日本語/翻訳)

struct TranslatedTextCard: View {
    let text: String
    let language: String
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Text(language)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                // コピーボタン
                if !text.isEmpty {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            // テキスト表示
            Text(text.isEmpty ? "翻訳結果がここに表示されます" : text)
                .font(.body)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Language Badge

struct LanguageBadge: View {
    let language: String
    let flag: String

    var body: some View {
        HStack(spacing: 4) {
            Text(flag)
            Text(language)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SourceTextCard(
            text: "Hello, how are you?",
            language: "English",
            isActive: true
        )

        TranslatedTextCard(
            text: "こんにちは、お元気ですか？",
            language: "日本語",
            isLoading: false
        )

        HStack {
            LanguageBadge(language: "EN", flag: "🇺🇸")
            LanguageBadge(language: "JA", flag: "🇯🇵")
        }
    }
    .padding()
}
