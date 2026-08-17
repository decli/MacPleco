import Foundation

/// Human-readable byte sizes.
///
/// Uses decimal units (1 KB = 1000 B) to agree with Finder — a cleaner that
/// reports 4.3 GB for what Finder calls 4.6 GB looks broken, whichever
/// convention is technically preferable.
///
/// Values carry three significant digits ("4.61 GB", "21.5 MB", "275 MB"),
/// which keeps column widths stable while staying precise enough that a user
/// can tell two similar rows apart.
public enum Bytes {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    public static func format(_ value: Int64) -> String {
        format(Double(value))
    }

    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let negative = value < 0
        var amount = abs(value)
        var unit = 0
        while amount >= 1000, unit < units.count - 1 {
            amount /= 1000
            unit += 1
        }

        let text: String
        if unit == 0 {
            text = String(format: "%.0f B", amount)
        } else {
            // Three significant digits: 9.87 / 98.7 / 987.
            let decimals: Int
            if amount < 10 {
                decimals = 2
            } else if amount < 100 {
                decimals = 1
            } else {
                decimals = 0
            }
            text = String(format: "%.\(decimals)f %@", amount, units[unit])
        }
        return negative ? "-" + text : text
    }

    /// Splits a formatted size so a view can typeset the number and the unit at
    /// different sizes — used by the hero readouts.
    public static func split(_ value: Int64) -> (number: String, unit: String) {
        let whole = format(value)
        guard let spaceIndex = whole.lastIndex(of: " ") else { return (whole, "") }
        return (
            String(whole[whole.startIndex..<spaceIndex]),
            String(whole[whole.index(after: spaceIndex)...])
        )
    }
}

/// Relative dates in the app's voice — short, plain, never a bare timestamp.
public enum RelativeTime {
    public static func describe(_ date: Date?) -> String {
        guard let date else { return t("未知", "Unknown") }
        let seconds = Date().timeIntervalSince(date)
        if seconds < 0 { return t("刚刚", "Just now") }

        let days = Int(seconds / 86_400)
        switch days {
        case 0:
            return t("今天", "Today")
        case 1:
            return t("昨天", "Yesterday")
        case 2..<30:
            return t("\(days) 天前", "\(days) days ago")
        case 30..<365:
            let months = max(1, days / 30)
            return t("\(months) 个月前", months == 1 ? "1 month ago" : "\(months) months ago")
        default:
            let years = max(1, days / 365)
            return t("\(years) 年前", years == 1 ? "1 year ago" : "\(years) years ago")
        }
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return t("\(days) 天 \(hours) 小时", "\(days)d \(hours)h") }
        if hours > 0 { return t("\(hours) 小时 \(minutes) 分", "\(hours)h \(minutes)m") }
        return t("\(minutes) 分钟", "\(minutes)m")
    }
}
