//
//  LargeTextScrollView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/23/26.
//
import SwiftUI

struct LargeTextScrollView: View {
    let fullText: String

    // 줄 바꿈 단위로 배열 분할 (또는 문단 단위)
    private var lines: [String] {
        fullText.components(separatedBy: .newlines)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line.isEmpty ? " " : line)
                        .font(.body)
                        .textSelection(.enabled) // 필요시 텍스트 선택 기능
                }
            }
            .padding()
        }
    }
}
