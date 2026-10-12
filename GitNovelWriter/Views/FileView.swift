//
//  FileView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//

// FileView.swift
import Foundation
import SwiftUI
#if canImport(SwiftGit2)
import SwiftGit2
#endif

struct FileView: View {
    let fileURL: URL

    private let largeFileThreshold: Int = 60 * 1024 // 60KB
    @State private var isLargeFile: Bool = false
    @State private var allowEditLargeFile: Bool = false
    @State private var saveTask: Task<Void, Never>? = nil

    @State private var textContent: String = ""
    @State private var selectedTab: FileTab = .editor
    @State private var commitHistory: [CommitHistoryItem] = []
    @State private var isLoadingHistory = false
    @State private var historyError: String?

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
                    commitHistoryView

                case .editor:
                    
                    LargeFileEditorView(fileURL: fileURL)
                }
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .task(id: fileURL) {
            loadFile()
            await loadCommitHistory()
        }
    }

    @ViewBuilder
    private var commitHistoryView: some View {
        if isLoadingHistory {
            ProgressView("변경 이력을 불러오는 중...")
        } else if let historyError {
            ContentUnavailableView("변경 이력을 불러올 수 없습니다", systemImage: "exclamationmark.triangle", description: Text(historyError))
        } else if commitHistory.isEmpty {
            ContentUnavailableView("변경 이력이 없습니다", systemImage: "clock.arrow.circlepath")
        } else {
            List(commitHistory) { commit in
                CommitRow(
                    author: commit.author,
                    date: commit.date.formatted(date: .abbreviated, time: .shortened),
                    message: commit.message
                )
            }
            .refreshable {
                await loadCommitHistory()
            }
        }
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

    private func loadCommitHistory() async {
        isLoadingHistory = true
        historyError = nil

        let result = await Task.detached(priority: .userInitiated) {
            Self.commitHistory(for: fileURL)
        }.value

        guard !Task.isCancelled else { return }

        switch result {
        case .success(let history):
            commitHistory = history
        case .failure(let error):
            commitHistory = []
            historyError = error.localizedDescription
        }

        isLoadingHistory = false
    }

    private nonisolated static func commitHistory(for fileURL: URL) -> Result<[CommitHistoryItem], Error> {
#if canImport(SwiftGit2)
        do {
            guard let repositoryRoot = repositoryRoot(containing: fileURL) else {
                throw CommitHistoryError.repositoryNotFound
            }

            let repository = try Repository.at(repositoryRoot).get()
            let head = try repository.HEAD().get()
            guard let branch = head as? Branch else {
                throw CommitHistoryError.detachedHead
            }

            let filePath = relativePath(of: fileURL, from: repositoryRoot)
            let commits = try repository.commits(in: branch).compactMap { result -> CommitHistoryItem? in
                let commit = try result.get()
                let changesFile = try repository.diff(for: commit).get().deltas.contains { delta in
                    delta.oldFile?.path == filePath || delta.newFile?.path == filePath
                }

                guard changesFile else { return nil }
                return CommitHistoryItem(
                    id: commit.oid.description,
                    author: commit.author.name,
                    date: commit.author.time,
                    message: commit.message.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            return .success(commits)
        } catch {
            return .failure(error)
        }
#else
        return .failure(CommitHistoryError.swiftGit2Unavailable)
#endif
    }

    private nonisolated static func repositoryRoot(containing fileURL: URL) -> URL? {
        let fileManager = FileManager.default
        var directory = fileURL.deletingLastPathComponent()

        while true {
            if fileManager.fileExists(atPath: directory.appendingPathComponent(".git").path) {
                return directory
            }

            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else {
                return nil
            }
            directory = parent
        }
    }

    private nonisolated static func relativePath(of fileURL: URL, from repositoryRoot: URL) -> String {
        let rootPath = repositoryRoot.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return String(filePath.dropFirst(rootPath.count + 1))
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

private struct CommitHistoryItem: Identifiable, Sendable {
    let id: String
    let author: String
    let date: Date
    let message: String
}

private enum CommitHistoryError: LocalizedError, Sendable {
    case repositoryNotFound
    case detachedHead
    case swiftGit2Unavailable

    var errorDescription: String? {
        switch self {
        case .repositoryNotFound:
            return "이 파일이 포함된 Git 저장소를 찾을 수 없습니다."
        case .detachedHead:
            return "분리된 HEAD 상태에서는 변경 이력을 표시할 수 없습니다."
        case .swiftGit2Unavailable:
            return "SwiftGit2를 사용할 수 없습니다."
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
                ForEach(chunks, id: \.self) { chunk in
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
    private let chunkSize: Int = 64 * 1024
    
    struct TextChunk: Identifiable {
        let id = UUID()
        let range: Range<String.Index>
        var text: String
    }
    
    @State private var fullText: String = ""
    @State private var chunks: [TextChunk] = []
    @State private var currentChunkIndex: Int = 0
    @State private var currentChunkText: String = ""
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var isLoaded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !isLoaded {
                ProgressView("파일을 여는 중...")
                    .padding()
            } else if chunks.isEmpty {
                Text("파일이 비어있거나 로드 실패")
            } else {
                HStack {
                    Button("◀ 이전") {
                        navigateChunk(offset: -1)
                    }
                    .disabled(currentChunkIndex == 0)
                    
                    Spacer()
                    Text("Chunk \(currentChunkIndex + 1) / \(chunks.count)")
                        .font(.caption)
                    Spacer()
                    Button("다음 ▶") {
                        navigateChunk(offset: 1)
                    }
                    .disabled(currentChunkIndex >= chunks.count - 1)
                }
                .padding(.horizontal)
                
                TextEditor(text: $currentChunkText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 300)
                    .padding(8)
                
                Button("저장") {
                    saveCurrentChunk()
                    saveAll()
                }
                .padding(.bottom)
            }
        }
        .onAppear(perform: { Task { await load() } })
    }
    
    private func load() async {
        do {
            let data = try Data(contentsOf: fileURL)
            let text = String(decoding: data, as: UTF8.self)
            let built = buildChunks(for: text)
            await MainActor.run {
                self.fullText = text
                self.chunks = built
                self.currentChunkIndex = 0
                self.currentChunkText = built.first?.text ?? ""
                self.isLoaded = true
            }
        } catch {
            await MainActor.run {
                self.fullText = "로드 실패: \(error.localizedDescription)"
                self.chunks = []
                self.isLoaded = true
            }
        }
    }
    
    private func buildChunks(for text: String) -> [TextChunk] {
        var result: [TextChunk] = []
        var start = text.startIndex
        while start < text.endIndex {
            let proposedEnd = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            var end = proposedEnd
            if end < text.endIndex {
                if let newline = text[start..<text.endIndex].lastIndex(of: "\n") {
                    let distance = text.distance(from: start, to: newline)
                    if distance > chunkSize / 2 {
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
    
    private func navigateChunk(offset: Int) {
        guard isLoaded, !chunks.isEmpty else { return }
        saveCurrentChunk()
        let newIndex = currentChunkIndex + offset
        if newIndex >= 0 && newIndex < chunks.count {
            currentChunkIndex = newIndex
            currentChunkText = chunks[newIndex].text
        }
    }
    
    private func saveCurrentChunk() {
        guard isLoaded, currentChunkIndex < chunks.count else { return }
        chunks[currentChunkIndex].text = currentChunkText
    }
    
    private func saveAll() {
        saveTask?.cancel()
        let combined = chunks.map { $0.text }.joined()
        self.fullText = combined
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await Task.detached { [combined] in
                try? combined.write(to: fileURL, atomically: true, encoding: .utf8)
            }.value
        }
    }
}

