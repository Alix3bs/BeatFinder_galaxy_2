import Foundation
import SwiftUI

@MainActor
final class LyricPadStore: ObservableObject {
    struct Entry: Codable, Hashable {
        var text: String
        var updatedAt: Date
    }

    @Published private(set) var entries: [String: Entry] = [:]

    private let defaultsKey = "beatfinder.lyric_pad.entries.v1"

    init() {
        load()
    }

    func text(for beatID: String) -> String {
        entries[beatID]?.text ?? ""
    }

    func update(_ text: String, for beatID: String) {
        let trimmedTrailing = text.replacingOccurrences(of: "\r\n", with: "\n")
        entries[beatID] = Entry(text: trimmedTrailing, updatedAt: Date())
        persist()
    }

    func statusText(for beatID: String) -> String {
        guard let entry = entries[beatID] else { return "Ready" }
        return entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ready" : "Saved"
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        entries = decoded
    }
}

struct BeatLyricPad: View {
    let beatID: String
    let beatTitle: String

    @EnvironmentObject private var lyricPadStore: LyricPadStore
    @State private var isExpanded = false
    @State private var draftText = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button {
                BeatHaptics.tap()
                withAnimation(MotionTokens.topModalSpring) {
                    isExpanded.toggle()
                }
                if isExpanded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isEditorFocused = true
                    }
                } else {
                    isEditorFocused = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Lyric Pad")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    Text(lyricPadStore.statusText(for: beatID))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BeatColors.textSecondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.74))
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.58))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(BeatPressableButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lyric Pad")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)

                            Text(beatTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(BeatColors.textSecondary)
                        }

                        Spacer()

                        Text(lyricPadStore.statusText(for: beatID))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BeatColors.accentBlue)
                    }

                    ZStack(alignment: .topLeading) {
                        if draftText.isEmpty {
                            Text("Write lyrics, bars, hooks, ideas…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(BeatColors.textTertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }

                        TextEditor(text: $draftText)
                            .focused($isEditorFocused)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 168)
                            .background(Color.clear)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.46))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(BeatColors.surfacePrimary.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .frame(maxWidth: 460)
        .onAppear {
            draftText = lyricPadStore.text(for: beatID)
        }
        .onChange(of: draftText) { _, newValue in
            lyricPadStore.update(newValue, for: beatID)
        }
    }
}
