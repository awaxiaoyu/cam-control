import SwiftUI

struct CloudChatPanel: View {
    @State private var selectedRoom = "Project"

    private let rooms = [
        CloudRoom(title: "Project", value: "No project selected - All Clips", icon: "folder.fill", color: BlackmagicCamStyle.activeBlue),
        CloudRoom(title: "Blackmagic Cloud", value: "Log in to Blackmagic Cloud", icon: "cloud.fill", color: BlackmagicCamStyle.cyan),
        CloudRoom(title: "Upload Status", value: "Waiting to Upload...", icon: "arrow.up.circle.fill", color: BlackmagicCamStyle.amber),
        CloudRoom(title: "Remote Cam Control", value: "No remote camera linked", icon: "dot.radiowaves.left.and.right", color: BlackmagicCamStyle.recordRed)
    ]

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 900
            HStack(spacing: 0) {
                cloudSidebar(compact: compact)
                    .frame(width: compact ? 150 : 220)
                Divider().overlay(.white.opacity(0.10))
                chatSurface(compact: compact)
            }
            .background(BlackmagicCamStyle.canvas)
        }
        // Firmware/update note: CloudChatPanel mirrors reversed ChatViewSidebar, ChatViewToolbar, ChatTableView, CloudLoginView and upload strings; use recovered Cloud/Upload/Project assets, and future protocol support should bind values without changing this hierarchy.
    }

    private func cloudSidebar(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                BMDAssetIcon(name: "Cloud", active: true, fallback: "cloud.fill", color: BlackmagicCamStyle.cyan, size: compact ? 12 : 15)
                Text(selectedRoom == "Project" ? "Short Film" : selectedRoom)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.top, compact ? 9 : 12)
            .padding(.bottom, compact ? 8 : 10)

            VStack(spacing: compact ? 6 : 8) {
                ForEach(rooms) { room in
                    Button {
                        withAnimation(.snappy(duration: 0.16)) { selectedRoom = room.title }
                    } label: {
                        CloudSidebarRoom(room: room, active: selectedRoom == room.title, compact: compact)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, compact ? 8 : 12)
            Spacer()
        }
        .background(
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.92)
                BMDAssetImage(name: "BmdCloudLogo", fallback: "cloud.fill", preserveOriginalColors: true)
                    .frame(width: compact ? 66 : 92, height: compact ? 22 : 30)
                    .opacity(0.035)
                    .padding(compact ? 8 : 12)
            }
        )
        // Firmware/update note: ChatViewSidebar mirrors screenshot: compact dark room list with active blue outline; BmdCloudLogo remains as a barely-visible recovered asset watermark.
    }

    private func chatSurface(compact: Bool) -> some View {
        VStack(spacing: 0) {
            chatToolbar(compact: compact)
            messagePane(compact: compact)
        }
        .background(Color(red: 0.040, green: 0.043, blue: 0.047))
        // Firmware/update note: ChatTableView occupies the full right surface in Blackmagic screenshots; project/upload info stays in sidebar/toolbars.
    }

    private func chatToolbar(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            Text(selectedRoom == "Project" ? "Short Film" : selectedRoom)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 13, weight: .heavy))
                .foregroundStyle(.white)
            Spacer()
            ForEach(["person.crop.circle.fill", "person.crop.circle", "person.crop.circle.badge.plus", "person.crop.circle"], id: \.self) { icon in
                Image(systemName: icon)
                    .font(.system(size: compact ? 12 : 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: compact ? 18 : 24, height: compact ? 18 : 24)
                    .background(.white.opacity(0.10), in: Circle())
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 7 : 9)
        .background(Color.black.opacity(0.74))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .bottom)
        // Firmware/update note: toolbar mirrors ChatViewToolbar screenshot: room title left, participant avatars right.
    }

    private func messagePane(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                    ChatBubble(author: "Melissa Williamson", text: "Morning! I will upload what I've been shooting as well.", time: "9:04 AM", outgoing: false, compact: compact)
                    ChatBubble(author: "You", text: "Hello!", time: "9:05 AM", outgoing: true, compact: compact)
                    ChatBubble(author: "You", text: "Yes. I will record more clips", time: "9:05 AM", outgoing: true, compact: compact)
                    ChatBubble(author: "You", text: "Hey, I've finished recording. More clips are uploading now", time: "9:18 AM", outgoing: true, compact: compact)
                    ChatBubble(author: "Michael Lee", text: "Thank you guys, nice work!", time: "9:21 AM", outgoing: false, compact: compact)
                    ChatBubble(author: "You", text: "Thank you!", time: "9:22 AM", outgoing: true, compact: compact)
                }
                .padding(.horizontal, compact ? 12 : 18)
                .padding(.vertical, compact ? 12 : 16)
            }

            HStack(spacing: compact ? 6 : 8) {
                Text("Message...")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.36))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, compact ? 10 : 12)
                    .padding(.vertical, compact ? 7 : 9)
                    .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 9)
            .background(.black.opacity(0.46))
            .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .top)
        }
        // Firmware/update note: ChatTableView is represented as compact left/right message bubbles with timestamps and bottom input field, matching recovered ChatTableView and screenshots.
    }

    private func syncPanel(compact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ProjectUploadInfo".uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(BlackmagicCamStyle.amber)
                CloudActionRow(title: "Auto Upload To Selected Project", value: "Off")
                CloudActionRow(title: "Enable Upload Only Over Wi-Fi", value: "On")
                CloudActionRow(title: "Sync Presets to Cloud Project", value: "Manual")
                CloudActionRow(title: "Upload Original", value: "Queued")
                CloudActionRow(title: "Upload Proxy", value: "Ready")

                Divider().overlay(.white.opacity(0.12))

                Text("BLACKMAGIC CLOUD")
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text("Log in to Blackmagic Cloud to\n access your projects")
                    .font(BlackmagicCamStyle.labelFont(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                Text("You have not created or been added to any Blackmagic Cloud project.")
                    .font(BlackmagicCamStyle.labelFont(size: 12, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
            }
            .padding(20)
        }
        .background(.black.opacity(0.28))
    }

    private func cloudToolbarPill(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            BMDAssetIcon(name: icon, active: true, fallback: BlackmagicReverseSpec.assetFallbackSystemImages[icon] ?? "cloud.fill", color: .white, size: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.50))
                Text(value)
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

private struct CloudRoom: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}

private struct CloudSidebarRoom: View {
    let room: CloudRoom
    let active: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 11) {
            BMDAssetIcon(name: assetName, active: active, fallback: room.icon, color: active ? .white : room.color, size: compact ? 15 : 18)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background((active ? room.color : room.color.opacity(0.14)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(room.title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(room.value)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(active ? 0.76 : 0.44))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 9 : 12)
        .background(active ? room.color.opacity(0.22) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(active ? room.color.opacity(0.55) : .white.opacity(0.08), lineWidth: 1))
    }

    private var assetName: String {
        switch room.title {
        case "Project": return "ProjectUpload"
        case "Blackmagic Cloud": return "BmdCloudSidebar"
        case "Upload Status": return "UploadToCloud"
        case "Remote Cam Control": return "CameraLinked"
        default: return "Cloud"
        }
    }
}

private struct ChatBubble: View {
    let author: String
    let text: String
    let time: String
    let outgoing: Bool
    let compact: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: compact ? 6 : 8) {
            if outgoing { Spacer(minLength: compact ? 60 : 110) }
            if !outgoing {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: compact ? 18 : 24, height: compact ? 18 : 24)
                    .overlay(Text(String(author.prefix(1))).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).foregroundStyle(.white.opacity(0.8)))
            }
            VStack(alignment: outgoing ? .trailing : .leading, spacing: 2) {
                if !outgoing {
                    Text(author)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Text(text)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 8 : 10)
                    .padding(.vertical, compact ? 6 : 8)
                    .background(outgoing ? BlackmagicCamStyle.activeBlue : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
                Text(time)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
            }
            if !outgoing { Spacer(minLength: compact ? 60 : 110) }
        }
        // Firmware/update note: bubble colors and alignment match Blackmagic Chat screenshots: blue outgoing, gray incoming, timestamps beside compact table rows.
    }
}

private struct ChatDateDivider: View {
    let title: String
    var body: some View {
        HStack {
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.42))
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
        }
    }
}

private struct ChatNewMessageDivider: View {
    var body: some View {
        HStack {
            Rectangle().fill(BlackmagicCamStyle.activeBlue.opacity(0.50)).frame(height: 1)
            Text("NEW MESSAGE")
                .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(BlackmagicCamStyle.cyan)
            Rectangle().fill(BlackmagicCamStyle.activeBlue.opacity(0.50)).frame(height: 1)
        }
    }
}

private struct CloudMessage: View {
    enum Tone { case cyan, blue, amber, red }
    let author: String
    let text: String
    let tone: Tone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 6) {
                Text(author.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(color)
                Text(text)
                    .font(BlackmagicCamStyle.labelFont(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.90))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.18), lineWidth: 1))
        }
    }

    private var color: Color {
        switch tone {
        case .cyan: return BlackmagicCamStyle.cyan
        case .blue: return BlackmagicCamStyle.activeBlue
        case .amber: return BlackmagicCamStyle.amber
        case .red: return BlackmagicCamStyle.recordRed
        }
    }
}

private struct CloudActionRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text(value.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(BlackmagicCamStyle.cyan)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(BlackmagicCamStyle.cyan.opacity(0.13), in: Capsule())
        }
        .padding(12)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}
