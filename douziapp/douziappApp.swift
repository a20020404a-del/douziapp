//
//  douziappApp.swift
//  douziapp
//
//  iOS同時通訳アプリ - メインエントリーポイント
//

import SwiftUI
import SwiftData

@main
struct douziappApp: App {
    @StateObject private var appSettings = AppSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TranslationRecord.self,
            TranslationSession.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
        .modelContainer(sharedModelContainer)
    }
}
