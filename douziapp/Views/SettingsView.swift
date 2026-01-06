//
//  SettingsView.swift
//  douziapp
//
//  設定画面
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // 言語設定
                languageSection

                // 音声設定
                audioSection

                // 一般設定
                generalSection

                // 統計情報
                statsSection

                // アプリ情報
                aboutSection
            }
            .navigationTitle("設定")
            .alert("設定をリセットしますか？", isPresented: $showingResetAlert) {
                Button("リセット", role: .destructive) {
                    appSettings.resetToDefaults()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("全ての設定がデフォルト値に戻ります。")
            }
        }
    }

    // MARK: - Sections

    private var languageSection: some View {
        Section {
            HStack {
                Label("入力言語", systemImage: "mic")
                Spacer()
                Text("🇺🇸 英語")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("出力言語", systemImage: "text.bubble")
                Spacer()
                Text("🇯🇵 日本語")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("言語設定")
        } footer: {
            Text("現在のバージョンでは英語→日本語のみ対応しています。")
        }
    }

    private var audioSection: some View {
        Section("音声設定") {
            Toggle(isOn: $appSettings.autoSpeak) {
                Label("自動読み上げ", systemImage: "speaker.wave.2")
            }

            VStack(alignment: .leading) {
                Label("読み上げ速度", systemImage: "speedometer")
                Slider(value: $appSettings.speechRate, in: 0...1) {
                    Text("速度")
                } minimumValueLabel: {
                    Text("遅")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("速")
                        .font(.caption2)
                }
            }

            VStack(alignment: .leading) {
                Label("音量", systemImage: "speaker.wave.3")
                Slider(value: $appSettings.volume, in: 0...1) {
                    Text("音量")
                } minimumValueLabel: {
                    Image(systemName: "speaker")
                        .font(.caption2)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3")
                        .font(.caption2)
                }
            }
        }
    }

    private var generalSection: some View {
        Section("一般設定") {
            Picker(selection: $appSettings.darkMode) {
                ForEach(DarkModeSetting.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label("外観", systemImage: "circle.lefthalf.filled")
            }

            Picker(selection: $appSettings.historyRetentionDays) {
                Text("7日").tag(7)
                Text("30日").tag(30)
                Text("90日").tag(90)
                Text("無制限").tag(365)
            } label: {
                Label("履歴保存期間", systemImage: "clock.arrow.circlepath")
            }

            Toggle(isOn: $appSettings.backgroundEnabled) {
                Label("バックグラウンド動作", systemImage: "arrow.triangle.2.circlepath")
            }

            Toggle(isOn: $appSettings.hapticFeedback) {
                Label("触覚フィードバック", systemImage: "hand.tap")
            }
        }
    }

    private var statsSection: some View {
        Section("統計") {
            HStack {
                Label("総翻訳回数", systemImage: "number")
                Spacer()
                Text("\(appSettings.totalTranslations)回")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("総使用時間", systemImage: "timer")
                Spacer()
                Text(formatMinutes(appSettings.totalMinutes))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        Section("アプリ情報") {
            HStack {
                Label("バージョン", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://example.com/terms")!) {
                Label("利用規約", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://example.com/privacy")!) {
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }

            Button(role: .destructive) {
                showingResetAlert = true
            } label: {
                Label("設定をリセット", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 60 {
            return "\(Int(minutes))分"
        }
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
        return "\(hours)時間\(mins)分"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
