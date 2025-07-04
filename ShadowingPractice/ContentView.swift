//
//  ContentView.swift
//  ShadowingPractice
//
//  Created by Apple on 2025/07/04.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingView()
                .tabItem {
                    Label("録音", systemImage: "mic.circle.fill")
                }
                .tag(0)
            
            PracticeView()
                .tabItem {
                    Label("練習", systemImage: "book.circle.fill")
                }
                .tag(1)
            
            // Placeholder for future results tab
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("結果・進捗")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text("練習結果と進捗状況がここに表示されます")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .navigationTitle("結果")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("結果", systemImage: "chart.bar.fill")
            }
            .tag(2)
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
}
