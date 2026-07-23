//
//  RepoCredentalView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//

import SwiftUI
#if canImport(SwiftGit2)
import SwiftGit2
#endif

#if canImport(SwiftGit2)
struct RepoCredentalView : View {
    @AppStorage("userName") var username: String = ""
    @AppStorage("token") var token: String = ""
    @State var credentials: Credentials? = nil
    var body: some View {
        Section("인증정보") {
            if let cre = credentials {
                
                switch cre {
                case .default:
                    Text("default")
                case .sshAgent:
                    Text("sshAgent")
                case .plaintext(username: "", password: ""):
                    Text("plainText")
                case .sshMemory(username: "", privateKey: "", passphrase: ""):
                    Text("sshMemory")
                default:
                    Text("other")
                }
                
            } else {
                HStack {
                    VStack{
                        TextField("userName", text: $username)
                        TextField("token", text: $token)
                    }
                    Button {
                        getCredentials()
                    } label: {
                        Text("Auth")
                    }
                    
                }
            }
                        
        }.onAppear {
            if !username.isEmpty && !token.isEmpty {
                getCredentials()
            }
        }
    }
    
    func getCredentials() {
        self.credentials = GitService.shared
            .createPATCredentials(username: username, token: token)
    }
}
#else
struct RepoCredentalView: View {
    var body: some View {
        Section("인증정보") {
            Text("Preview에서는 SwiftGit2가 비활성화되어 인증 UI를 표시할 수 없습니다.")
                .foregroundColor(.secondary)
        }
    }
}
#endif
