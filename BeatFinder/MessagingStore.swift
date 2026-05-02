import Foundation
import SwiftUI

struct DirectMessageEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let senderID: String
    let text: String
    let sentAt: Date

    init(
        id: UUID = UUID(),
        senderID: String,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.senderID = senderID
        self.text = text
        self.sentAt = sentAt
    }
}

struct DirectMessageThread: Identifiable, Codable, Hashable {
    let id: String
    let userID: String
    var username: String
    var handle: String
    var avatarName: String?
    var lastSeenText: String
    var messages: [DirectMessageEntry]
    var updatedAt: Date

    var lastMessagePreview: String {
        messages.last?.text ?? ""
    }
}

@MainActor
final class MessagingStore: ObservableObject {
    @Published private(set) var threads: [String: DirectMessageThread] = [:]

    private let defaultsKey = "beatfinder.direct_messages.v1"
    private let currentUserID = "current-user"

    init() {
        load()
    }

    func thread(for user: ProfileUser) -> DirectMessageThread {
        let key = user.id.uuidString

        if let existing = threads[key] {
            return existing
        }

        let thread = DirectMessageThread(
            id: key,
            userID: key,
            username: user.name,
            handle: user.handle,
            avatarName: user.avatarName,
            lastSeenText: "Last seen recently",
            messages: [],
            updatedAt: Date()
        )

        threads[key] = thread
        persist()
        return thread
    }

    func sendMessage(_ text: String, to user: ProfileUser) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var thread = thread(for: user)
        thread.username = user.name
        thread.handle = user.handle
        thread.avatarName = user.avatarName
        thread.updatedAt = Date()
        thread.messages.append(
            DirectMessageEntry(
                senderID: currentUserID,
                text: trimmed
            )
        )

        threads[thread.id] = thread
        persist()
    }

    func messageGroups(for user: ProfileUser) -> [DirectMessageEntry] {
        thread(for: user).messages
    }

    func isCurrentUserMessage(_ message: DirectMessageEntry) -> Bool {
        message.senderID == currentUserID
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: DirectMessageThread].self, from: data) else { return }
        threads = decoded
    }
}

struct DirectMessageThreadView: View {
    let user: ProfileUser

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messagingStore: MessagingStore
    @State private var draftMessage = ""
    @FocusState private var isComposerFocused: Bool

    private var thread: DirectMessageThread {
        messagingStore.thread(for: user)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if thread.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
                .background(Color.black.opacity(0.96))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                BeatHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())

            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(thread.lastSeenText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BeatColors.textSecondary)
            }

            Spacer()

            Button {
                BeatHaptics.tap()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())
        }
        .padding(.horizontal, BeatLayout.screenHorizontal)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var avatar: some View {
        Group {
            if let avatarName = user.avatarName, !avatarName.isEmpty {
                Image(avatarName)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(BeatColors.surfaceSecondary)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(BeatColors.surfaceSecondary)
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BeatColors.accentBlue)
                )

            Text("Start the conversation")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text("Send \(user.name) your first message about beats, collabs, or feedback.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BeatColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BeatLayout.screenHorizontal)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(thread.messages) { message in
                        HStack {
                            if messagingStore.isCurrentUserMessage(message) {
                                Spacer(minLength: 52)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.text)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        messagingStore.isCurrentUserMessage(message)
                                            ? BeatColors.subscriptionRoyalBlue
                                            : BeatColors.surfaceSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(BeatColors.textTertiary)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: messagingStore.isCurrentUserMessage(message) ? .trailing : .leading
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: messagingStore.isCurrentUserMessage(message) ? .trailing : .leading)
                            .id(message.id)

                            if !messagingStore.isCurrentUserMessage(message) {
                                Spacer(minLength: 52)
                            }
                        }
                    }
                }
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .onAppear {
                scrollToLatest(proxy)
            }
            .onChange(of: thread.messages.count) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Write a message…", text: $draftMessage, axis: .vertical)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .focused($isComposerFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BeatColors.surfaceSecondary)
                )

            Button {
                let message = draftMessage
                draftMessage = ""
                messagingStore.sendMessage(message, to: user)
                BeatHaptics.success()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BeatColors.accentBlueText)
                    .frame(width: 52, height: 52)
                    .background(BeatColors.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(BeatPressableButtonStyle())
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, BeatLayout.screenHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastID = thread.messages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}
