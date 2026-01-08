//
//  Language.swift
//  douziapp
//
//  対応言語定義 - 世界中の言語をサポート
//

import Foundation

struct Language: Identifiable, Hashable {
    let id: String // 言語コード (例: "en", "zh", "ko")
    let speechCode: String // 音声認識用コード (例: "en-US", "zh-CN")
    let name: String // 日本語名
    let localName: String // 現地語名
    let flag: String // 国旗絵文字

    static let allLanguages: [Language] = [
        // 東アジア
        Language(id: "ja", speechCode: "ja-JP", name: "日本語", localName: "日本語", flag: "🇯🇵"),
        Language(id: "zh", speechCode: "zh-CN", name: "中国語（簡体）", localName: "简体中文", flag: "🇨🇳"),
        Language(id: "zh-TW", speechCode: "zh-TW", name: "中国語（繁体）", localName: "繁體中文", flag: "🇹🇼"),
        Language(id: "ko", speechCode: "ko-KR", name: "韓国語", localName: "한국어", flag: "🇰🇷"),

        // 東南アジア
        Language(id: "th", speechCode: "th-TH", name: "タイ語", localName: "ไทย", flag: "🇹🇭"),
        Language(id: "vi", speechCode: "vi-VN", name: "ベトナム語", localName: "Tiếng Việt", flag: "🇻🇳"),
        Language(id: "id", speechCode: "id-ID", name: "インドネシア語", localName: "Bahasa Indonesia", flag: "🇮🇩"),
        Language(id: "ms", speechCode: "ms-MY", name: "マレー語", localName: "Bahasa Melayu", flag: "🇲🇾"),
        Language(id: "tl", speechCode: "fil-PH", name: "フィリピン語", localName: "Filipino", flag: "🇵🇭"),

        // 南アジア
        Language(id: "hi", speechCode: "hi-IN", name: "ヒンディー語", localName: "हिन्दी", flag: "🇮🇳"),
        Language(id: "bn", speechCode: "bn-IN", name: "ベンガル語", localName: "বাংলা", flag: "🇧🇩"),
        Language(id: "ta", speechCode: "ta-IN", name: "タミル語", localName: "தமிழ்", flag: "🇮🇳"),

        // 西アジア・中東
        Language(id: "ar", speechCode: "ar-SA", name: "アラビア語", localName: "العربية", flag: "🇸🇦"),
        Language(id: "fa", speechCode: "fa-IR", name: "ペルシャ語", localName: "فارسی", flag: "🇮🇷"),
        Language(id: "he", speechCode: "he-IL", name: "ヘブライ語", localName: "עברית", flag: "🇮🇱"),
        Language(id: "tr", speechCode: "tr-TR", name: "トルコ語", localName: "Türkçe", flag: "🇹🇷"),

        // ヨーロッパ（西）
        Language(id: "en", speechCode: "en-US", name: "英語", localName: "English", flag: "🇺🇸"),
        Language(id: "en-GB", speechCode: "en-GB", name: "英語（イギリス）", localName: "English (UK)", flag: "🇬🇧"),
        Language(id: "fr", speechCode: "fr-FR", name: "フランス語", localName: "Français", flag: "🇫🇷"),
        Language(id: "de", speechCode: "de-DE", name: "ドイツ語", localName: "Deutsch", flag: "🇩🇪"),
        Language(id: "es", speechCode: "es-ES", name: "スペイン語", localName: "Español", flag: "🇪🇸"),
        Language(id: "pt", speechCode: "pt-PT", name: "ポルトガル語", localName: "Português", flag: "🇵🇹"),
        Language(id: "pt-BR", speechCode: "pt-BR", name: "ポルトガル語（ブラジル）", localName: "Português (Brasil)", flag: "🇧🇷"),
        Language(id: "it", speechCode: "it-IT", name: "イタリア語", localName: "Italiano", flag: "🇮🇹"),
        Language(id: "nl", speechCode: "nl-NL", name: "オランダ語", localName: "Nederlands", flag: "🇳🇱"),

        // ヨーロッパ（北）
        Language(id: "sv", speechCode: "sv-SE", name: "スウェーデン語", localName: "Svenska", flag: "🇸🇪"),
        Language(id: "no", speechCode: "nb-NO", name: "ノルウェー語", localName: "Norsk", flag: "🇳🇴"),
        Language(id: "da", speechCode: "da-DK", name: "デンマーク語", localName: "Dansk", flag: "🇩🇰"),
        Language(id: "fi", speechCode: "fi-FI", name: "フィンランド語", localName: "Suomi", flag: "🇫🇮"),

        // ヨーロッパ（東）
        Language(id: "ru", speechCode: "ru-RU", name: "ロシア語", localName: "Русский", flag: "🇷🇺"),
        Language(id: "pl", speechCode: "pl-PL", name: "ポーランド語", localName: "Polski", flag: "🇵🇱"),
        Language(id: "uk", speechCode: "uk-UA", name: "ウクライナ語", localName: "Українська", flag: "🇺🇦"),
        Language(id: "cs", speechCode: "cs-CZ", name: "チェコ語", localName: "Čeština", flag: "🇨🇿"),
        Language(id: "hu", speechCode: "hu-HU", name: "ハンガリー語", localName: "Magyar", flag: "🇭🇺"),
        Language(id: "ro", speechCode: "ro-RO", name: "ルーマニア語", localName: "Română", flag: "🇷🇴"),
        Language(id: "el", speechCode: "el-GR", name: "ギリシャ語", localName: "Ελληνικά", flag: "🇬🇷"),

        // アフリカ
        Language(id: "sw", speechCode: "sw-KE", name: "スワヒリ語", localName: "Kiswahili", flag: "🇰🇪"),
        Language(id: "af", speechCode: "af-ZA", name: "アフリカーンス語", localName: "Afrikaans", flag: "🇿🇦"),
    ]

    /// 日本語
    static let japanese = allLanguages.first { $0.id == "ja" }!

    /// 英語（デフォルト）
    static let english = allLanguages.first { $0.id == "en" }!

    /// 日本語以外の言語（入力言語として選択可能）
    static var sourceLanguages: [Language] {
        allLanguages.filter { $0.id != "ja" }
    }

    /// IDで言語を検索
    static func find(by id: String) -> Language? {
        allLanguages.first { $0.id == id }
    }
}
