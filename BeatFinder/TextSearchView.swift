import SwiftUI

struct TextSearchView: View {
    @EnvironmentObject private var search: SearchService

    @State private var query: String = ""
    @State private var selectedBeat: SearchBeat?

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search beats…", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, BeatLayout.screenHorizontal)
                .padding(.top, 12)
                .onChange(of: query) { _, newValue in
                    Task { await search.search(newValue) }
                }

            if search.isLoading {
                ProgressView()
                    .padding(.top, 4)
            }

            if !search.statusText.isEmpty {
                Text(search.statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            List(search.results) { beat in
                Button {
                    selectedBeat = beat
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(beat.title)
                            .font(.system(size: 16, weight: .bold))
                        Text("\(beat.producer) • \(beat.genre)\(beat.bpm.map { " • \($0) BPM" } ?? "")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedBeat) { beat in
            BeatResultView(
                model: BeatResultModel(
                    id: beat.id.uuidString,
                    title: beat.title,
                    artist: beat.producer,
                    bpm: beat.bpm ?? 0,
                    genre: beat.genre,
                    releaseDate: Date(),
                    artworkName: "nest_music"
                )
            )
        }
    }
}
