import SwiftUI

struct CloudChatPanel: View {
    private let rooms = [
        CloudRoom(title: "Project", value: "No project selected - All Clips", icon: "folder.fill", color: BlackmagicCamStyle.activeBlue),
        CloudRoom(title: "Blackmagic Cloud", value: "Log in to access projects and chat", icon: "cloud.fill", color: BlackmagicCamStyle.cyan),
        CloudRoom(title: "Upload Status", value: "Waiting to Upload...", icon: "arrow.up.circle.fill", color: BlackmagicCamStyle.amber),
        CloudRoom(title: "Remote Cam Control", value: "No remote camera linked", icon: "dot.radiowaves.left.and.right", color: BlackmagicCamStyle.recordRed)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    BMSectionHeader(
                        eyebrow: "Blackmagic Cloud",
                        title: "Project chat and sync",
                        subtitle: "Mirrors reversed Cloud, Chat, Upload Status, Project, Members, Remote Cam Control strings from the IPA."
                    )
                    Spacer(minLength: 12)
                    BMStatusPill(title: "Cloud", value: "Offline", color: BlackmagicCamStyle.amber)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                    ForEach(rooms) { room in
                        CloudRoomCard(room: room)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CHAT IN PROJECT")
                            .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(BlackmagicCamStyle.cyan)
                        CloudMessage(author: "Camera Operator", text: "Log in to Blackmagic Cloud to access your project chat.")
                        CloudMessage(author: "System", text: "You have not created or been added to any Blackmagic Cloud project.")
                        CloudMessage(author: "Upload", text: "Upload clips, proxy, or original media once a project is selected.")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .blackmagicPanel(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("SYNC CONTROLS")
                            .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(BlackmagicCamStyle.cyan)
                        CloudActionRow(title: "Auto Upload To Selected Project", value: "Off")
                        CloudActionRow(title: "Enable Upload Only Over Wi-Fi", value: "On")
                        CloudActionRow(title: "Sync Presets to Cloud Project", value: "Manual")
                        CloudActionRow(title: "Upload Original", value: "Queued")
                        CloudActionRow(title: "Upload Proxy", value: "Ready")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .blackmagicPanel(cornerRadius: 22)
                }
            }
            .padding(24)
        }
        .background(BlackmagicCamStyle.studioGradient)
        // Firmware/update note: the visible Cloud/Chat shell is driven by reversed strings; when camera/cloud protocol support is added, bind values here instead of changing navigation hierarchy.
    }
}

private struct CloudRoom: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}

private struct CloudRoomCard: View {
    let room: CloudRoom

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: room.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(room.color)
                    .frame(width: 42, height: 42)
                    .background(room.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                Text(room.title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(room.color)
            }
            Text(room.value)
                .font(BlackmagicCamStyle.labelFont(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(minHeight: 142, alignment: .top)
        .blackmagicPanel(cornerRadius: 22)
    }
}

private struct CloudMessage: View {
    let author: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(author.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(BlackmagicCamStyle.mutedText)
            Text(text)
                .font(BlackmagicCamStyle.labelFont(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.90))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    }
}
