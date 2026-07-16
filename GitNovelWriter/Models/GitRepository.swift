//
//  GitRepository.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//


// GitRepository.swift
import Foundation
import SwiftData
import SwiftGit2

@Model
final class GitRepository {
    @Attribute(.unique) var id: UUID
    var name: String
    var remoteURLString: String
    var localPath: String // App Documents 폴더 내의 상대 경로
    var createdAt: Date
    
    init(name: String, remoteURLString: String, localPath: String) {
        self.id = UUID()
        self.name = name
        self.remoteURLString = remoteURLString
        self.localPath = localPath
        self.createdAt = Date()
    }
}

extension GitRepository {
    // 로컬 파일 경로 URL 반환
    var localURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(localPath)
    }
}
