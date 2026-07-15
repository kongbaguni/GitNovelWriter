//
//  Item.swift
//  GitNovelWriter
//
//  Created by 서창열 on 7/15/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
