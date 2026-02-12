import SwiftUI

struct HoneycombGrid: View {
    let coaches: [Coach]
    let onTap: (Coach) -> Void

    private let orbSize: CGFloat = 64
    private let spacing: CGFloat = 6
    private let labelHeight: CGFloat = 20

    private var cellHeight: CGFloat { orbSize + labelHeight + 4 }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = orbSize + spacing
            let cols = max(1, Int(geometry.size.width / cellWidth))
            let rows = chunked(coaches, size: cols)
            let rowHeight = cellHeight * 0.88 + spacing

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: spacing) {
                        ForEach(row) { coach in
                            coachOrb(for: coach)
                                .onTapGesture { onTap(coach) }
                        }
                    }
                    .padding(.leading, rowIndex % 2 == 1 ? cellWidth / 2 : 0)
                    .frame(height: cellHeight)
                    .offset(y: rowIndex == 0 ? 0 : -CGFloat(rowIndex) * (cellHeight - rowHeight))
                }
            }
        }
        .frame(height: gridHeight)
    }

    private var gridHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 48
        let cellWidth = orbSize + spacing
        let cols = max(1, Int(screenWidth / cellWidth))
        let rowCount = (coaches.count + cols - 1) / cols
        let rowHeight = cellHeight * 0.88 + spacing
        return CGFloat(rowCount) * rowHeight + (cellHeight - rowHeight)
    }

    @ViewBuilder
    private func coachOrb(for coach: Coach) -> some View {
        VStack(spacing: 4) {
            OrbAvatar(colors: coach.orbColorPair, size: orbSize)
                .frame(width: orbSize, height: orbSize)

            Text(coach.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: orbSize)
    }

    private func chunked(_ array: [Coach], size: Int) -> [[Coach]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
}
