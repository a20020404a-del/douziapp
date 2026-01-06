//
//  HistoryView.swift
//  douziapp
//
//  翻訳履歴一覧画面
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranslationRecord.timestamp, order: .reverse) private var records: [TranslationRecord]

    @State private var searchText = ""
    @State private var showingDeleteAlert = false

    var filteredRecords: [TranslationRecord] {
        if searchText.isEmpty {
            return records
        }
        return records.filter {
            $0.sourceText.localizedCaseInsensitiveContains(searchText) ||
            $0.translatedText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedRecords: [(String, [TranslationRecord])] {
        let grouped = Dictionary(grouping: filteredRecords) { record in
            record.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("履歴")
            .searchable(text: $searchText, prompt: "検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !records.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("全て削除", systemImage: "trash")
                            }

                            Button {
                                exportHistory()
                            } label: {
                                Label("エクスポート", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("全ての履歴を削除しますか？", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    deleteAllRecords()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("履歴がありません", systemImage: "clock")
        } description: {
            Text("翻訳を開始すると、ここに履歴が表示されます。")
        }
    }

    private var listView: some View {
        List {
            ForEach(groupedRecords, id: \.0) { date, dayRecords in
                Section(date) {
                    ForEach(dayRecords) { record in
                        HistoryRowView(record: record)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteRecord(record)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func deleteRecord(_ record: TranslationRecord) {
        modelContext.delete(record)
    }

    private func deleteAllRecords() {
        for record in records {
            modelContext.delete(record)
        }
    }

    private func exportHistory() {
        let text = records.map { record in
            """
            [\(record.timestamp.formatted())]
            EN: \(record.sourceText)
            JA: \(record.translatedText)
            """
        }.joined(separator: "\n\n---\n\n")

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let record: TranslationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 時刻
            Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)

            // 原文
            HStack(alignment: .top, spacing: 8) {
                Text("🇺🇸")
                    .font(.caption)
                Text(record.sourceText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            // 翻訳
            HStack(alignment: .top, spacing: 8) {
                Text("🇯🇵")
                    .font(.caption)
                Text(record.translatedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: TranslationRecord.self, inMemory: true)
}
