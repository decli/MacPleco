import SwiftUI
import Observation

/// The sections of the app, in sidebar order.
///
/// Ordering is deliberate and is the product's core claim: a non-technical
/// person should be able to stop after `overview` and still have done the right
/// thing. Everything below it is progressive disclosure.
///
/// Named `Destination` rather than `Section` to stay clear of SwiftUI's own
/// `Section` view.
public enum Destination: String, CaseIterable, Identifiable, Hashable {
    case overview
    case clean
    case apps
    case space
    case tune
    case monitor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: return t("概览", "Overview")
        case .clean: return t("清理", "Clean")
        case .apps: return t("应用", "Apps")
        case .space: return t("空间", "Space")
        case .tune: return t("优化", "Tune-Up")
        case .monitor: return t("监控", "Monitor")
        }
    }

    public var subtitle: String {
        switch self {
        case .overview: return t("一眼看清这台 Mac", "Your Mac at a glance")
        case .clean: return t("腾出可以回收的空间", "Reclaim wasted space")
        case .apps: return t("卸载应用，管理开机启动", "Uninstall apps, manage login items")
        case .space: return t("看看空间都去哪儿了", "See where the space went")
        case .tune: return t("修复与刷新系统缓存", "Repair and refresh system caches")
        case .monitor: return t("实时性能与进程", "Live performance and processes")
        }
    }

    public var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .clean: return "sparkles"
        case .apps: return "square.stack.3d.up"
        case .space: return "chart.pie"
        case .tune: return "wrench.adjustable"
        case .monitor: return "waveform.path.ecg"
        }
    }
}

/// Root application state. One instance lives for the lifetime of the window
/// and is handed to every view through the environment.
@Observable
@MainActor
public final class AppModel {
    public var destination: Destination = .overview
    public var language: Lang = Localization.current

    /// Feature models are created eagerly but scan lazily, so switching
    /// sections never discards in-flight work or computed results.
    public let clean = CleanModel()
    public let apps = AppsModel()
    public let space = SpaceModel()
    public let tune = TuneModel()
    public let monitor = MonitorModel()
    public let storage = StorageModel()

    public init() {}

    public func switchLanguage(to lang: Lang) {
        Localization.set(lang)
        language = lang
    }

    /// Called once when the window appears.
    public func bootstrap() {
        storage.refresh()
    }
}
