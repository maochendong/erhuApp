import SwiftUI

@main
struct ErhuApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onAppear {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isShowing: $showOnboarding)
                        .onDisappear {
                            hasSeenOnboarding = true
                        }
                }
        }
    }
}
