//
//  Item.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: A leftover from Xcode's starter template. Only ContentView.swift
//  uses it, and nothing opens that screen, so both can be deleted.
//

import Foundation
import SwiftData

// @Model is SwiftData's way of saving objects on the phone. The real app data comes from the
// server instead.
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
