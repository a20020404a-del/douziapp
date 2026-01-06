//
//  TranslationRecord.swift
//  douziapp
//
//  翻訳履歴データモデル（SwiftData）
//

import Foundation
import SwiftData

@Model
final class TranslationRecord {
    var id: UUID
    var sourceText: String
    var translatedText: String
    var sourceLanguage: String
    var targetLanguage: String
    var timestamp: Date
    var session: TranslationSession?

    init(
        sourceText: String,
        translatedText: String,
        sourceLanguage: String = "en",
        targetLanguage: String = "ja",
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
    }
}

@Model
final class TranslationSession {
    var id: UUID
    var title: String
    var startTime: Date
    var endTime: Date?
    @Relationship(deleteRule: .cascade, inverse: \TranslationRecord.session)
    var records: [TranslationRecord]

    init(title: String = "", startTime: Date = Date()) {
        self.id = UUID()
        self.title = title.isEmpty ? Self.defaultTitle(for: startTime) : title
        self.startTime = startTime
        self.records = []
    }

    static func defaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return "セッション \(formatter.string(from: date))"
    }

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "進行中" }
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)分\(seconds)秒"
    }
}
