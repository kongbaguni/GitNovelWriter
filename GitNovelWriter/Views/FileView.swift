//
//  FileView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//

// FileView.swift
import SwiftUI

struct FileView: View {
    let fileURL: URL

    private let largeFileThreshold: Int = 60 * 1024 // 60KB
    @State private var isLargeFile: Bool = false
    @State private var allowEditLargeFile: Bool = false
    @State private var saveTask: Task<Void, Never>? = nil

    @State private var textContent: String = ""
    @State private var selectedTab: FileTab = .editor

    enum FileTab: String, CaseIterable, Identifiable {
        case plainText = "텍스트"
        case markdown = "렌더링"
        case history = "변경 이력"
        case editor = "편집기"

        var id: String { self.rawValue }
    }

    var isMarkdown: Bool {
        fileURL.pathExtension.lowercased() == "md"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("뷰 모드", selection: $selectedTab) {
                ForEach(FileTab.allCases) { tab in
                    if tab != .markdown || isMarkdown {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            ZStack {
                switch selectedTab {
                case .plainText:
                    LargeTextScrollView(fullText: textContent)

                case .markdown:
                    LargeMarkdownView(fullText: textContent)

                case .history:
                    List {
                        //TODO: 실제 Git 라이브러리 탑재 시 commit history 데이터 바인딩
                        CommitRow(author: "Github User", date: "방금 전", message: "Updated \(fileURL.lastPathComponent)")
                        CommitRow(author: "System", date: "1일 전", message: "First import")
                    }

                case .editor:
                    
                    LargeFileEditorView(fileURL: fileURL)
                }
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .onAppear(perform: loadFile)
    }

    private func loadFile() {
        Task {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let size = attrs[.size] as? NSNumber {
                    await MainActor.run { self.isLargeFile = size.intValue > largeFileThreshold }
                }

                let data = try Data(contentsOf: fileURL)
                let str = String(decoding: data, as: UTF8.self)
                await MainActor.run { self.textContent = str }
            } catch {
                await MainActor.run {
                    self.textContent = "파일을 불러오는 도중 오류가 발생했습니다: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveFile() {
        // Backward compatibility if needed elsewhere
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let text = self.textContent
        let url = self.fileURL
        saveTask = Task { @MainActor in
            // Debounce ~0.7s
            try? await Task.sleep(nanoseconds: 700_000_000)
            // Perform file write off main actor
            await Task.detached {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }.value
        }
    }
}

// 변경 이력을 그려내기 위한 Sub-view
struct CommitRow: View {
    let author: String
    let date: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack {
                Text(author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChunkedTextView: View {
    let text: String
    let chunkSize: Int = 64 * 1024

    private var chunks: [Substring] {
        var result: [Substring] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            result.append(text[start..<end])
            start = end
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                    Text(String(chunk))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

struct LargeFileEditorView: View {
    let fileURL: URL
    // Use a moderate chunk size to balance performance and memory.
    private let chunkSize: Int = 64 * 1024

    struct TextChunk: Identifiable {
        let id = UUID()
        let range: Range<String.Index>
        var text: String
    }

    @State private var fullText: String = ""
    @State private var chunks: [TextChunk] = []
    @State private var activeIndex: Int = 0
    @State private var saveTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(chunks.indices, id: \.self) { idx in
                        if idx == activeIndex {
                            TextEditor(text: binding(for: idx))
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 300)
                                .padding(8)
                                .id(idx)
                                .onChange(of: chunks[idx].text) {
                                    scheduleSave()
                                }
                                .onAppear { maybeSetActive(to: idx) }
                        } else {
                            Text(chunks[idx].text)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .id(idx)
                                .onAppear { maybeSetActive(to: idx) }
                        }
                    }
                }
            }
            .task {
                await load()
                proxy.scrollTo(activeIndex, anchor: .top)
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(get: { chunks[index].text }, set: { newValue in
            chunks[index].text = newValue
            // Also update fullText lazily on save to avoid frequent large copies.
        })
    }

    private func maybeSetActive(to index: Int) {
        if abs(activeIndex - index) <= 1 {
            activeIndex = index
        }
    }

    private func load() async {
        do {
            let data = try Data(contentsOf: fileURL)
            // Decode once to a single String (still efficient for MB class files).
            let text = String(decoding: data, as: UTF8.self)
            let built = buildChunks(for: text)
            await MainActor.run {
                self.fullText = text
                self.chunks = built
            }
        } catch {
            await MainActor.run {
                self.fullText = "로드 실패: \(error.localizedDescription)"
                self.chunks = [TextChunk(range: fullText.startIndex..<fullText.endIndex, text: fullText)]
            }
        }
    }

    private func buildChunks(for text: String) -> [TextChunk] {
        // Split on character boundaries near chunkSize to avoid breaking UTF-8 scalars.
        var result: [TextChunk] = []
        var start = text.startIndex
        while start < text.endIndex {
            let proposedEnd = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            var end = proposedEnd
            if end < text.endIndex {
                // Try to end at a newline boundary for better UX.
                if let newline = text[start..<text.endIndex].lastIndex(of: "\n") {
                    let distance = text.distance(from: start, to: newline)
                    if distance > chunkSize / 2 { // avoid tiny trailing chunk
                        end = text.index(after: newline)
                    }
                }
            }
            let range = start..<end
            let slice = String(text[range])
            result.append(TextChunk(range: range, text: slice))
            start = end
        }
        return result
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await saveAll()
        }
    }

    @MainActor
    private func saveAll() async {
        // Rebuild the full text from current chunks and write once.
        let combined = chunks.map { $0.text }.joined()
        self.fullText = combined
        await Task.detached { [combined] in
            try? combined.write(to: fileURL, atomically: true, encoding: .utf8)
        }.value
    }
}
