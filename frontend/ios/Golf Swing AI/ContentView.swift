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

            SettingsView()
                .environmentObject(themeManager)
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "gear.fill" : "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .tint(Color("AccentColor"))
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToAnalysisTab"))) { _ in
            selectedTab = 1
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}