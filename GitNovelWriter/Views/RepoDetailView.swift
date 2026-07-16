//
//  RepoDetailView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//


// RepoDetailView.swift
import SwiftUI

struct RepoDetailView: View {
    let repo: GitRepository
    let currentDirectory: URL

    @State private var items: [URL] = []

    var body: some View {
        List {
            ForEach(items, id: \.self) { itemURL in
                let isDirectory = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

                if isDirectory {
                    NavigationLink(destination: RepoDetailView(repo: repo, currentDirectory: itemURL)) {
                        Label(itemURL.lastPathComponent, systemImage: "folder.fill")
                            .foregroundColor(.blue)
                    }
                } else {
                    NavigationLink(destination: FileView(fileURL: itemURL)) {
                        Label(itemURL.lastPathComponent, systemImage: "doc.text")
                    }
                }
            }
        }
        .navigationTitle(currentDirectory.lastPathComponent)
        .onAppear(perform: loadContents)
    }

    private func loadContents() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: currentDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            // 폴더가 리스트 상단에 오도록 우선 정렬 후 가나다 정렬
            self.items = contents.sorted { (url1, url2) -> Bool in
                let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir1 != isDir2 {
                    return isDir1 && !isDir2
                }
                return url1.lastPathComponent.lowercased() < url2.lastPathComponent.lowercased()
            }
        } catch {
            print("디렉토리 읽기 실패: \(error)")
        }
    }
}