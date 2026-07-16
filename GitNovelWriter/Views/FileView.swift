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

    private let largeFileThreshold: Int = 300 * 1024 // 300KB
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
                    if isLargeFile {
                        ChunkedTextView(text: textContent)
                    } else {
                        ScrollView {
                            Text(textContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }

                case .markdown:
                    ScrollView {
                        // iOS 15+ 에서는 AttributedString이 Markdown 포맷을 기본 내장 지원합니다.
                        if let attributedString = try? AttributedString(markdown: textContent) {
                            Text(attributedString)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        } else {
                            Text(textContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }

                case .history:
                    List {
                        // 실제 Git 라이브러리 탑재 시 commit history 데이터 바인딩
                        CommitRow(author: "Github User", date: "방금 전", message: "Updated \(fileURL.lastPathComponent)")
                        CommitRow(author: "System", date: "1일 전", message: "First import")
                    }

                case .editor:
                    VStack(spacing: 8) {
                        if isLargeFile && !allowEditLargeFile {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("대용량 파일입니다 (300KB+). 편집 시 성능 저하가 발생할 수 있습니다.")
                                    .font(.footnote)
                                    .foregroundColor(.orange)
                                Button("그래도 편집하기") { allowEditLargeFile = true }
                            }
                            .padding(8)
                        } else {
                            TextEditor(text: $textContent)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .onChange(of: textContent) {
                                    scheduleSave()
                                }
                        }
                    }
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
