//
//  RepoListView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//


// RepoListView.swift
import SwiftUI
import SwiftData

struct RepoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GitRepository.createdAt, order: .reverse) private var repositories: [GitRepository]
    @State private var isShowingCloneSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(repositories) { repo in
                    NavigationLink(destination: RepoDetailView(repo: repo, currentDirectory: repo.localURL)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repo.name)
                                .font(.headline)
                            Text(repo.remoteURLString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteRepositories)
            }
            .navigationTitle("로컬 저장소")
            .toolbar {
                Button(action: { isShowingCloneSheet = true }) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .sheet(isPresented: $isShowingCloneSheet) {
                CloneRepoView()
            }
            .overlay {
                if repositories.isEmpty {
                    ContentUnavailableView(
                        "저장소 없음",
                        systemImage: "folder.badge.plus",
                        description: Text("상단의 클론 버튼을 눌러 첫 GitHub 저장소를 연동해보세요.")
                    )
                }
            }
        }
    }

    private func deleteRepositories(offsets: IndexSet) {
        for index in offsets {
            let repo = repositories[index]
            // 1. 실제 디렉토리 파일 삭제
            try? FileManager.default.removeItem(at: repo.localURL)
            // 2. SwiftData DB 모델 삭제
            modelContext.delete(repo)
        }
    }
}


