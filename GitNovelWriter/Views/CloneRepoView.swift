//
//  CloneRepoView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//


// CloneRepoView.swift
import SwiftUI
import SwiftData

struct CloneRepoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var repoURLString = ""
    @State private var isCloning = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            RepoCredentalView()
            Form {
                Section("Git 저장소 정보") {
                    TextField("https://github.com/user/repo.git", text: $repoURLString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("저장소 클론")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCloning {
                        ProgressView()
                    } else {
                        Button("클론") {
                            Task { await performClone() }
                        }
                        .disabled(repoURLString.isEmpty)
                    }
                }
            }
        }
    }

    private func performClone() async {
        
        
        
        guard let url = URL(string: repoURLString),
              let repoName = repoURLString.split(separator: "/").last?.replacingOccurrences(of: ".git", with: "") else {
            errorMessage = "올바르지 않은 Git URL 주소입니다."
            return
        }

        
        
        isCloning = true
        errorMessage = nil

        let uniqueDirName = "\(repoName)_\(UUID().uuidString.prefix(6))"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documents.appendingPathComponent(uniqueDirName)

        let (repository, cloneError) = await GitService.shared.clone(remoteURL: url, to: localURL)

        if let cloneError {
            self.errorMessage = "클론에 실패했습니다: \(cloneError.localizedDescription)"
        } else if repository != nil {
            // 클론 성공: 로컬 저장소 정보 저장
            let newRepo = GitRepository(
                name: repoName,
                remoteURLString: repoURLString,
                localPath: uniqueDirName
            )
            modelContext.insert(newRepo)
            do {
                try modelContext.save()
                dismiss()
            } catch {
                self.errorMessage = "저장에 실패했습니다: \(error.localizedDescription)"
            }
        } else {
            // repository와 error가 모두 nil인 비정상 상황 방어
            self.errorMessage = "알 수 없는 오류로 클론에 실패했습니다."
        }

        isCloning = false
    }
}

