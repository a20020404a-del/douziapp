//
//  ContentView.swift
//  douziapp
//
//  メインナビゲーションビュー
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .translation

    enum Tab {
        case translation
        case history
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TranslationView()
                .tabItem {
                    Label("通訳", systemImage: "mic.fill")
                }
                .tag(Tab.translation)

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.fill")
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
