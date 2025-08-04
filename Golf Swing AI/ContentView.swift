import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Premium background
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color.green.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        Text("Home")
                    }
                    .tag(0)

                SwingAnalysisView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "video.fill" : "video")
                        Text("Analysis")
                    }
                    .tag(1)
                
                CaddieChatView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "message.fill" : "message")
                        Text("CaddieChat")
                    }
                    .tag(2)

                BallTrackingView()
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "scope" : "scope")
                        Text("Tracking")
                    }
                    .tag(3)
                
                SettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(authManager)
                    .tabItem {
                        Image(systemName: selectedTab == 4 ? "gear.fill" : "gear")
                        Text("Settings")
                    }
                    .tag(4)
            }
            .accentColor(.green)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar(.visible, for: .tabBar)
            .tabViewStyle(.automatic)
            .preferredColorScheme(themeManager.effectiveColorScheme)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            selectedTab = 0
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}