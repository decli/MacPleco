import Foundation
import CoreGraphics

/// Squarified treemap layout.
///
/// The naive "slice and dice" split produces slivers that are impossible to
/// click and impossible to compare by eye. Squarifying keeps tiles close to
/// square, which is what makes a treemap readable at a glance — the whole
/// reason to draw one instead of a list.
///
/// Bruls, Huizing & van Wijk (2000).
public enum Treemap {

    public static func layout(values: [Int64], in rect: CGRect) -> [CGRect] {
        let doubles = values.map { CGFloat(max(0, $0)) }
        return layout(values: doubles, in: rect)
    }

    public static func layout(values: [CGFloat], in rect: CGRect) -> [CGRect] {
        var result = [CGRect](repeating: .zero, count: values.count)
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else { return result }

        // Convert weights into areas that exactly fill the rectangle.
        let scale = (rect.width * rect.height) / total
        let areas = values.map { $0 * scale }

        var free = rect
        var index = 0

        while index < areas.count {
            let side = min(free.width, free.height)
            guard side > 0 else { break }

            // Extend the current row while doing so improves the worst aspect
            // ratio in it; stop at the first item that would make it worse.
            var end = index
            var rowSum: CGFloat = 0
            var rowMin = CGFloat.greatestFiniteMagnitude
            var rowMax: CGFloat = 0
            var bestWorst = CGFloat.greatestFiniteMagnitude

            while end < areas.count {
                let area = areas[end]
                let sum = rowSum + area
                let minimum = min(rowMin, area)
                let maximum = max(rowMax, area)
                let candidate = worstRatio(sum: sum, minimum: minimum, maximum: maximum, side: side)

                if end > index, candidate > bestWorst { break }

                bestWorst = candidate
                rowSum = sum
                rowMin = minimum
                rowMax = maximum
                end += 1
            }

            guard rowSum > 0 else { break }
            let thickness = rowSum / side

            if free.width >= free.height {
                // The row becomes a column down the left edge.
                var y = free.minY
                for position in index..<end {
                    let height = (areas[position] / rowSum) * free.height
                    result[position] = CGRect(x: free.minX, y: y, width: thickness, height: height)
                    y += height
                }
                free = CGRect(
                    x: free.minX + thickness,
                    y: free.minY,
                    width: max(0, free.width - thickness),
                    height: free.height
                )
            } else {
                var x = free.minX
                for position in index..<end {
                    let width = (areas[position] / rowSum) * free.width
                    result[position] = CGRect(x: x, y: free.minY, width: width, height: thickness)
                    x += width
                }
                free = CGRect(
                    x: free.minX,
                    y: free.minY + thickness,
                    width: free.width,
                    height: max(0, free.height - thickness)
                )
            }

            index = end
        }

        return result
    }

    private static func worstRatio(
        sum: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        side: CGFloat
    ) -> CGFloat {
        guard sum > 0, minimum > 0 else { return .greatestFiniteMagnitude }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * maximum / sumSquared, sumSquared / (sideSquared * minimum))
    }
}
