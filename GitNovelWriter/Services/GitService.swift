//
//  GitService.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//

import Foundation
#if canImport(SwiftGit2)
import SwiftGit2
#endif

#if !canImport(SwiftGit2)
// Minimal stubs for preview builds to avoid linking SwiftGit2
enum GitServiceError: LocalizedError {
    case missingCredentials
    case cloneFailed(String)
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing Git credentials. Please sign in first."
        case .cloneFailed(let message):
            return "Clone failed: \(message)"
        }
    }
}

// Provide a lightweight GitService that compiles without SwiftGit2
class GitService {
    static let shared = GitService()
    private var _username: String? = nil
    private var _token: String? = nil
    func signInWithAccessToken(username: String, token: String) { _username = username; _token = token }
    var username: String? { _username }
    var token: String? { _token }
    func clone(remoteURL: URL, to localURL: URL, transferProgress: ((Int, Int) -> Void)? = nil, checkoutProgress: ((String, Int, Int) -> Void)? = nil) -> (Any?, Error?) {
        return (nil, GitServiceError.cloneFailed("SwiftGit2 is unavailable in Preview builds."))
    }
    func clone(remoteURL: URL, to localURL: URL, transferProgress: ((Int, Int) -> Void)? = nil, checkoutProgress: ((String, Int, Int) -> Void)? = nil) async -> (Any?, Error?) {
        return (nil, GitServiceError.cloneFailed("SwiftGit2 is unavailable in Preview builds."))
    }
    func createPATCredentials(username: String, token: String) -> String { "stub" }
}
#endif

#if canImport(SwiftGit2)
enum GitServiceError: LocalizedError {
    case missingCredentials
    case cloneFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing Git credentials. Please sign in first."
        case .cloneFailed(let message):
            return "Clone failed: \(message)"
        }
    }
}

class GitService {
    static let shared = GitService()
    
    private var _username: String? = nil
    private var _token: String? = nil
    
    func signInWithAccessToken(username: String, token: String) {
        _username = username
        _token = token
    }
    
    var username: String? {
        _username
    }
    
    var token: String? {
        _token
    }
    
    private func makeCredentials() -> Credentials? {
        guard let user = _username, let token = _token else { return nil }
        return Credentials.plaintext(username: user, password: token)
    }
    
    /// Synchronous clone with optional progress handlers
    func clone(remoteURL: URL,
               to localURL: URL,
               transferProgress: ((Int, Int) -> Void)? = nil,
               checkoutProgress: ((String, Int, Int) -> Void)? = nil) -> (Repository?, Error?) {
        
        guard let credentials = makeCredentials() else {
            return (nil, GitServiceError.missingCredentials)
        }
        
        let result = Repository.clone(from: remoteURL, to: localURL, credentials: credentials)
        
        do {
            return try (result.get(), nil)
        } catch {
            return (nil, GitServiceError.cloneFailed(error.localizedDescription))
        }
    }
    
    /// Async clone with optional progress handlers
    func clone(remoteURL: URL,
               to localURL: URL,
               transferProgress: ((Int, Int) -> Void)? = nil,
               checkoutProgress: ((String, Int, Int) -> Void)? = nil) async -> (Repository?, Error?) {
        
        guard let credentials = makeCredentials() else {
            return (nil, GitServiceError.missingCredentials)
        }
        
        let result = Repository.clone(from: remoteURL, to: localURL, credentials: credentials)
        
        do {
            return try (result.get(), nil)
        } catch {
            return (nil, GitServiceError.cloneFailed(error.localizedDescription))
        }
    }
    
    /// Create SwiftGit2 Credentials using a Personal Access Token (PAT)
    /// - Parameters:
    ///   - username: The Git service username (often your GitHub username or "x-access-token").
    ///   - token: The personal access token string.
    /// - Returns: SwiftGit2 Credentials value for plaintext auth.
    func createPATCredentials(username: String, token: String) -> Credentials {
        // Persist these for subsequent operations if desired
        self._username = username
        self._token = token
        return Credentials.plaintext(username: username, password: token)
    }
}
#endif
