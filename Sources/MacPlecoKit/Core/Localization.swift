import Foundation

/// The UI languages MacPleco ships with.
public enum Lang: String, CaseIterable, Identifiable, Sendable {
    case zh
    case en

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

/// A deliberately tiny localisation layer.
///
/// A `.xcstrings` catalogue would mean shipping resource bundles and resolving
/// them at runtime; with two languages and an in-app switcher, a pair of
/// literals at each call site is easier to review (translator and developer see
/// the same line) and cannot desynchronise from the code.
///
/// Views re-render on a language change because the root view is keyed on the
/// current language — see `RootView`.
public enum Localization {
    private static let defaultsKey = "com.macpleco.language"

    public private(set) static var current: Lang = {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let stored = Lang(rawValue: raw) {
            return stored
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zh : .en
    }()

    public static func set(_ lang: Lang) {
        current = lang
        UserDefaults.standard.set(lang.rawValue, forKey: defaultsKey)
    }
}

/// Returns the string for the active language.
public func t(_ zh: String, _ en: String) -> String {
    Localization.current == .zh ? zh : en
}
