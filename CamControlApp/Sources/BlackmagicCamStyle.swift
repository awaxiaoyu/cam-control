import SwiftUI

enum BlackmagicCamStyle {
    static let canvas = Color(red: 0.006, green: 0.008, blue: 0.012)
    static let monitor = Color(red: 0.028, green: 0.033, blue: 0.038)
    static let rail = Color(red: 0.012, green: 0.022, blue: 0.036)
    static let railElevated = Color(red: 0.026, green: 0.045, blue: 0.068)
    static let panel = Color.white.opacity(0.075)
    static let panelStrong = Color.white.opacity(0.12)
    static let hairline = Color.white.opacity(0.16)
    static let mutedText = Color.white.opacity(0.62)
    static let strongText = Color.white.opacity(0.94)
    static let activeBlue = Color(red: 0.16, green: 0.45, blue: 0.94)
    static let cyan = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let recordRed = Color(red: 0.98, green: 0.12, blue: 0.09)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let okGreen = Color(red: 0.35, green: 0.88, blue: 0.48)

    static let studioGradient = LinearGradient(
        colors: [
            Color(red: 0.008, green: 0.012, blue: 0.018),
            Color(red: 0.012, green: 0.028, blue: 0.046),
            Color.black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func labelFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if weight == .heavy || weight == .black {
            return .custom("Lato-Heavy", size: size)
        }
        if weight == .bold || weight == .semibold {
            return .custom("Lato-Bold", size: size)
        }
        if weight == .light {
            return .custom("Lato-Light", size: size)
        }
        return .custom("Lato-Regular", size: size)
    }

    static func readoutFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        weight == .heavy ? .custom("Lato-Timecode-Heavy", size: size) : .custom("Lato-Bold", size: size)
    }

    static func timecodeFont(size: CGFloat) -> Font {
        .custom("Lato-Timecode-Heavy", size: size)
    }
}

extension View {
    func blackmagicPanel(cornerRadius: CGFloat = 18, borderOpacity: Double = 0.14) -> some View {
        self
            .background(BlackmagicCamStyle.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
    }

    func blackmagicButtonShell(cornerRadius: CGFloat = 14, active: Bool = false) -> some View {
        self
            .background(
                active ? BlackmagicCamStyle.activeBlue.opacity(0.22) : BlackmagicCamStyle.railElevated,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(active ? BlackmagicCamStyle.activeBlue.opacity(0.72) : BlackmagicCamStyle.hairline, lineWidth: 1)
            )
    }
}

struct BMStatusPill: View {
    let title: String
    let value: String
    var color: Color = BlackmagicCamStyle.cyan

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(title.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                .foregroundStyle(BlackmagicCamStyle.mutedText)
            Text(value)
                .font(BlackmagicCamStyle.readoutFont(size: 12, weight: .semibold))
                .foregroundStyle(BlackmagicCamStyle.strongText)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.46), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        // Firmware/update note: keep status pill values sourced from controller state so future camera firmware changes only update property mapping, not UI chrome.
    }
}

struct BMSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(BlackmagicCamStyle.cyan)
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(BlackmagicCamStyle.labelFont(size: 13, weight: .medium))
                .foregroundStyle(BlackmagicCamStyle.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BMEmptyState: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(BlackmagicCamStyle.cyan)
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: 18, weight: .heavy))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(BlackmagicCamStyle.labelFont(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(BlackmagicCamStyle.mutedText)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .blackmagicPanel(cornerRadius: 22)
    }
}
