//
//  ContentView.swift
//  mobiledev
//
//  Created by 🍋💻 on 25/05/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            SwiftUITerminalView()
                .navigationTitle("MobileDev Terminal")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
    }
}

#Preview {
    ContentView()
}
