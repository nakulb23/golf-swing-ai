import Foundation

  struct Constants {
      // API Configuration - Production server  
      static let baseURL = "https://golfai.duckdns.org:8443"

      struct API {
          static let health = "/health"
          static let chat = "/chat"
          static let predict = "/predict"
          static let trackBall = "/track-ball"
          static let docs = "/docs"
      }

      struct Messages {
          static let apiError = "Unable to connect to Golf Swing AI service"
          static let videoError = "Unable to process video"
          static let networkError = "Please check your internet connection"
          static let connectionTest = "Testing connection to AI analysis server..."
          static let connectionSuccess = "Connected to AI analysis server"
          static let connectionFailed = "Failed to connect to AI server"
      }
  }
//
//  Constants.swift
//  Golf Swing AI
//
//  Created by Nakul Bhatnagar on 6/5/25.
//

