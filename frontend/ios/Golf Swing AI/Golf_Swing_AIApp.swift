//
//  Golf_Swing_AIApp.swift
//  Golf Swing AI
//
//  Created by Nakul Bhatnagar on 6/5/25.
//

import SwiftUI
import GoogleSignIn

@main
struct Golf_Swing_AIApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var themeManager = ThemeManager()
    
    init() {
        // Configure Google Sign-In as early as possible
        configureGoogleSignIn()
    }
    
    private func configureGoogleSignIn() {
        // Perform configuration on a background queue to avoid blocking
        DispatchQueue.global(qos: .background).async {
            guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let plist = NSDictionary(contentsOfFile: path),
                  let clientId = plist["CLIENT_ID"] as? String else {
                print("❌ Failed to load GoogleService-Info.plist or CLIENT_ID")
                return
            }
            
            // Configure on main queue
            DispatchQueue.main.async {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
                print("✅ Google Sign-In configured successfully")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MinimalLaunchScreen()
                .environmentObject(authManager)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
                .tint(Color("AccentColor"))
                .ignoresSafeArea(.all)
                .onAppear {
                    // Configure tab bar appearance
                    let tabBarAppearance = UITabBarAppearance()
                    tabBarAppearance.configureWithOpaqueBackground()
                    tabBarAppearance.backgroundColor = UIColor.systemBackground
                    tabBarAppearance.shadowColor = UIColor.clear
                    
                    // Set icon colors
                    UITabBar.appearance().standardAppearance = tabBarAppearance
                    UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                    UITabBar.appearance().tintColor = UIColor(Color("AccentColor"))
                    UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
                }
                .onOpenURL { url in
                    // Handle Google Sign-In URLs
                    GIDSignIn.sharedInstance.handle(url)
                    
                }
        }
    }
}
