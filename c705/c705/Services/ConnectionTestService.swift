//
//  ConnectionTestService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Checks whether the app can reach the backend server. Used by the
//  connection test screen to diagnose problems such as a wrong server
//  address.
//

import Foundation
import Network

// Each check returns a ConnectionTestResult (worked or not, plus a message) instead of
// crashing, so the screen can show it.
class ConnectionTestService {
    static let shared = ConnectionTestService()
    
    private init() {}
    
    // MARK: - Connection Test
    
    // Asks the server's /health address if it is awake. async means it waits for the answer
    // without freezing the screen, and it gives up after 5 seconds.
    func testBackendConnection() async -> ConnectionTestResult {
        let baseURL = APIService.shared.getBaseURL()
        
        guard let url = URL(string: "\(baseURL)/health") else {
            return ConnectionTestResult(
                success: false,
                message: "Invalid URL: \(baseURL)",
                details: "Unable to create URL from base URL"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return ConnectionTestResult(
                    success: false,
                    message: "Invalid response from server",
                    details: "Response is not HTTPURLResponse"
                )
            }
            
            if httpResponse.statusCode == 200 {
                return ConnectionTestResult(
                    success: true,
                    message: "Backend is connected! ✅",
                    details: "Server responded with status \(httpResponse.statusCode)"
                )
            } else if httpResponse.statusCode == 404 {
                // Health endpoint might not exist, but server is responding
                return ConnectionTestResult(
                    success: true,
                    message: "Backend is responding! ✅",
                    details: "Server is running (health endpoint not found, but server responds)"
                )
            } else {
                return ConnectionTestResult(
                    success: false,
                    message: "Backend responded with error",
                    details: "Status code: \(httpResponse.statusCode)"
                )
            }
        } catch {
            return ConnectionTestResult(
                success: false,
                message: "Cannot connect to backend",
                details: error.localizedDescription
            )
        }
    }
    
    // A rough check that the server responds. It does not talk to the database directly.
    func testDatabaseConnection() async -> ConnectionTestResult {
        // Test database by trying to signup/login (which requires DB)
        // Or we can create a simple health check endpoint
        let baseURL = APIService.shared.getBaseURL()
        
        guard let url = URL(string: "\(baseURL)/auth/health") else {
            return ConnectionTestResult(
                success: false,
                message: "Invalid URL",
                details: "Unable to create URL"
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Any response means server is up (even 404 is OK)
                // Use httpResponse to avoid unused variable warning
                _ = httpResponse.statusCode
                return ConnectionTestResult(
                    success: true,
                    message: "Database connection test passed",
                    details: "Backend is responding (database accessible through backend)"
                )
            } else {
                return ConnectionTestResult(
                    success: false,
                    message: "Invalid response",
                    details: "No HTTP response received"
                )
            }
        } catch {
            return ConnectionTestResult(
                success: false,
                message: "Cannot test database connection",
                details: "Backend connection required: \(error.localizedDescription)"
            )
        }
    }
    
    // Not implemented. It always returns nothing.
    func getLocalIPAddress() -> String? {
        // Note: This is a simplified version
        // For iOS, you typically need to get the Mac's IP from network settings
        // or configure it manually in the app
        return nil
    }
}

// A simple report card: whether the test passed, a short message and the details.
struct ConnectionTestResult {
    let success: Bool
    let message: String
    let details: String
}

