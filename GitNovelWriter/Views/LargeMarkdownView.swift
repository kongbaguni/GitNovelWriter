//
//  LargeMarkdownView.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/23/26.
//


import SwiftUI
import MarkdownUI

struct LargeMarkdownView: View {
    let fullText: String

    // 1. 대용량 텍스트를 문단(Paragraphs) 단위로 파싱 (빈 줄 기준 분할)
    // 4만 자 전체를 한 번에 렌더링하지 않고 블록 단위로 쪼갭니다.
    private var markdownBlocks: [String] {
        fullText.components(separatedBy: "\n\n")
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(markdownBlocks.enumerated()), id: \.offset) { index, block in
                    if !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Markdown(block)
                            .markdownTheme(.gitHub) // 기본 스타일 (GitHub 스타일 적용 가능)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}
