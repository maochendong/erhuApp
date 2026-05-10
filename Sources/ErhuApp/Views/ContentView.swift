import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PracticeView()
                .tabItem {
                    Label("练习", systemImage: "music.mic")
                }
                .tag(0)

            ScoreLibraryView()
                .tabItem {
                    Label("曲库", systemImage: "music.note.list")
                }
                .tag(1)

            ProgressView()
                .tabItem {
                    Label("进度", systemImage: "chart.bar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
