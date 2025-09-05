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
                    
                    // Configure Google Sign-In from GoogleService-Info.plist
                    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                       let plist = NSDictionary(contentsOfFile: path),
                       let clientId = plist["CLIENT_ID"] as? String {
                        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
                    }
                    
                }
                .onOpenURL { url in
                    // Handle Google Sign-In URLs
                    GIDSignIn.sharedInstance.handle(url)
                    
                }
        }
    }
}
