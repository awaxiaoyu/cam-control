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
                    .frame(width: compact ? 190 : 260)
                Divider().overlay(.white.opacity(0.10))
                chatSurface(compact: compact)
            }
            .background(BlackmagicCamStyle.canvas)
        }
        // Firmware/update note: CloudChatPanel mirrors reversed ChatViewSidebar, ChatViewToolbar, ChatTableView, CloudLoginView and upload strings; future protocol support should bind values without changing this hierarchy.
    }

    private func cloudSidebar(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BLACKMAGIC CLOUD")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text("ChatViewSidebar")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 18 : 22, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Project / Members / Upload / Remote")
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.top, compact ? 14 : 20)
            .padding(.bottom, compact ? 10 : 14)

            ForEach(rooms) { room in
                Button {
                    withAnimation(.snappy(duration: 0.16)) { selectedRoom = room.title }
                } label: {
                    CloudSidebarRoom(room: room, active: selectedRoom == room.title, compact: compact)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, compact ? 8 : 12)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                BMStatusPill(title: "Cloud", value: "Offline", color: BlackmagicCamStyle.amber)
                BMStatusPill(title: "Members", value: "0", color: .white.opacity(0.62))
            }
            .padding(compact ? 12 : 18)
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.94), BlackmagicCamStyle.rail.opacity(0.94)], startPoint: .top, endPoint: .bottom)
        )
    }

    private func chatSurface(compact: Bool) -> some View {
        VStack(spacing: 0) {
            chatToolbar(compact: compact)
            HStack(spacing: 0) {
                messagePane(compact: compact)
                if !compact {
                    Divider().overlay(.white.opacity(0.10))
                    syncPanel(compact: compact)
                        .frame(width: 330)
                }
            }
        }
        .background(BlackmagicCamStyle.studioGradient)
    }

    private func chatToolbar(compact: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ChatViewToolbar".uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text(selectedRoom == "Project" ? "Chat in Project" : selectedRoom)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 22 : 28, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer()
            cloudToolbarPill("Project", "All Clips", icon: "folder")
            cloudToolbarPill("Upload", "Proxy", icon: "arrow.up.circle")
            cloudToolbarPill("Login", "Offline", icon: "person.crop.circle")
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 10 : 14)
        .background(.black.opacity(0.62))
        .overlay(Rectangle().fill(.white.opacity(0.10)).frame(height: 1), alignment: .bottom)
    }

    private func messagePane(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                    ChatDateDivider(title: "TODAY")
                    CloudMessage(author: "Blackmagic Cloud", text: "Log in to Blackmagic Cloud to access your projects chat.", tone: .cyan)
                    CloudMessage(author: "Project", text: "No project selected - All Clips", tone: .blue)
                    ChatNewMessageDivider()
                    CloudMessage(author: "Upload Status", text: "Waiting to Upload... Original and proxy queues will appear here.", tone: .amber)
                    CloudMessage(author: "Remote Cam Control", text: "No remote camera linked. Remote camera monitor-only state is ready.", tone: .red)
                }
                .padding(compact ? 16 : 24)
            }

            HStack(spacing: 10) {
                Text("Message")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 12 : 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.36), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
                Button {
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: compact ? 14 : 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: compact ? 40 : 46, height: compact ? 40 : 46)
                        .background(BlackmagicCamStyle.activeBlue, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(compact ? 14 : 18)
            .background(.black.opacity(0.42))
            .overlay(Rectangle().fill(.white.opacity(0.10)).frame(height: 1), alignment: .top)
        }
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

                Text("CloudLoginView".uppercased())
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
            Image(systemName: icon)
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
