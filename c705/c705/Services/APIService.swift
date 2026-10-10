//
//  APIService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//

import Foundation

#if targetEnvironment(simulator)
    // Running on iOS Simulator
#else
    // Running on physical device
#endif

class APIService {
    static let shared = APIService()
    
    // Base URL configuration
    // Automatically detects simulator vs physical device
    // IMPORTANT: For Apple Sign In on physical devices, you MUST use HTTPS (e.g., ngrok)
    // Local IP addresses will timeout and fail on real devices
    private var baseURL: String {
        if let customURL = UserDefaults.standard.string(forKey: "customBackendURL"), !customURL.isEmpty {
            return customURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        if let productionURL = UserDefaults.standard.string(forKey: "productionBackendURL"), !productionURL.isEmpty {
            return productionURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return "https://api.c705.online"
    }
    
    private var authToken: String?
    
    // Custom URLSession configuration to suppress verbose network logging
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = false // Don't wait for connectivity, fail fast
        configuration.urlCache = nil // Disable caching to avoid stale data
        return URLSession(configuration: configuration)
    }()
    
    private init() {}
    
    // Public method to get base URL (for connection testing)
    func getBaseURL() -> String {
        return baseURL
    }
    
    // Method to set custom backend URL (for physical devices)
    func setCustomBackendURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "customBackendURL")
    }
    
    // MARK: - Authentication
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    func clearAuthToken() {
        self.authToken = nil
    }
    
    // MARK: - Request Helpers
    
    private func createRequest(endpoint: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set timeout to 30 seconds to prevent premature timeouts
        request.timeoutInterval = 30.0
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        do {
            // Reduced logging to minimize console noise
            // Only log request URL, not full headers
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Only log errors, not successful responses
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Only log error response body for non-common errors
                if httpResponse.statusCode != 404 && httpResponse.statusCode != 401 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Error Response (Status \(httpResponse.statusCode)): \(errorString.prefix(200))")
                    }
                }
                
                // Try to decode error message from backend
                // Handle both NestJS error format and custom error format
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for message field first (most common)
                    if let message = errorJson["message"] as? String, !message.isEmpty {
                        throw APIError.httpErrorWithMessage(httpResponse.statusCode, message)
                    }
                    // Fallback to error field
                    if let error = errorJson["error"] as? String, !error.isEmpty {
                        throw APIError.httpErrorWithMessage(httpResponse.statusCode, error)
                    }
                }
                
                // Default error messages for common status codes
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.httpErrorWithMessage(401, "Invalid email or password. Please try again.")
                case 400:
                    throw APIError.httpErrorWithMessage(400, "Invalid request. Please check your information and try again.")
                case 500:
                    throw APIError.httpErrorWithMessage(500, "Server error. Please try again later.")
                default:
                    throw APIError.httpError(httpResponse.statusCode)
                }
            }
            
            do {
                let decoder = JSONDecoder()
                // Use .useDefaultKeys to respect custom CodingKeys mappings
                // This ensures "access_token" -> accessToken mapping works correctly
                // Models with custom CodingKeys (like AuthResponse) need this
                decoder.keyDecodingStrategy = .useDefaultKeys
                
                // Try decoding - only log on failure
                let decoded = try decoder.decode(T.self, from: data)
                return decoded
            } catch let decodeError as DecodingError {
                // Print detailed decoding error
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ Failed to decode response. JSON: \(jsonString)")
                }
                print("❌ Decoding Error Details:")
                print("   - Type: \(type(of: decodeError))")
                switch decodeError {
                case .typeMismatch(let type, let context):
                    print("   - Type Mismatch: Expected \(type), but found different type")
                    print("   - Context: \(context.debugDescription)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .valueNotFound(let type, let context):
                    print("   - Value Not Found: Expected \(type)")
                    print("   - Context: \(context.debugDescription)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .keyNotFound(let key, let context):
                    print("   - Key Not Found: \(key.stringValue)")
                    print("   - Context: \(context.debugDescription)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .dataCorrupted(let context):
                    print("   - Data Corrupted")
                    print("   - Context: \(context.debugDescription)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                @unknown default:
                    print("   - Unknown decoding error: \(decodeError)")
                }
                throw APIError.decodingError(decodeError)
            } catch {
                // Print decoding error details
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ Failed to decode response. JSON: \(jsonString.prefix(500))")
                }
                print("❌ Decoding Error: \(error)")
                throw APIError.decodingError(error)
            }
        } catch let urlError as URLError {
            // Suppress verbose logging for common network errors that are expected
            // Handle different error types appropriately
            switch urlError.code {
            case .cancelled:
                // Request was cancelled - this is usually not an error, just ignore it silently
                // Don't log or throw - just return empty/default response
                throw APIError.networkError("Request was cancelled")
            case .timedOut:
                // Timeout errors - suppress console logging but still throw
                // The low-level network framework errors will still appear but we won't add to them
                throw APIError.networkError("Request timed out. The server may be unavailable. Please try again.")
            case .notConnectedToInternet, .networkConnectionLost:
                // Log connectivity issues
                print("❌ Network Error: No internet connection")
                throw APIError.networkError("No internet connection. Please check your network and try again.")
            case .cannotFindHost, .cannotConnectToHost:
                // Log connection failures
                print("❌ Network Error: Cannot connect to server at \(baseURL)")
                let errorMsg = "Cannot connect to server at \(baseURL). Please check:\n1. Backend is running (npm run start:dev)\n2. Correct URL (Simulator: localhost, Device: Mac's IP)\n3. Same WiFi network (for physical device)"
                throw APIError.networkError(errorMsg)
            default:
                // Only log significant errors
                print("❌ Network Error: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))")
                
                // Check for SSL errors
                if urlError.code == .serverCertificateUntrusted || 
                   urlError.code == .serverCertificateHasBadDate ||
                   urlError.code == .serverCertificateHasUnknownRoot ||
                   urlError.code == .secureConnectionFailed {
                    print("   - SSL Certificate Error Detected!")
                }
                
                // Check for ATS blocking
                if urlError.code == .appTransportSecurityRequiresSecureConnection {
                    print("   - App Transport Security (ATS) Error!")
                }
                
                throw APIError.networkError("Network error: \(urlError.localizedDescription)")
            }
        } catch let apiError as APIError {
            // Rethrow API errors (404, 500, etc.) without wrapping or logging again
            throw apiError
        } catch {
            // Catch any other errors
            print("❌ Unexpected error: \(error)")
            throw APIError.networkError("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Auth Endpoints
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let requestBody = LoginRequest(email: email, password: password)
        
        // Debug: Print request details
        if let jsonData = try? JSONEncoder().encode(requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Login Request Body: \(jsonString)")
        }
        
        let body = try JSONEncoder().encode(requestBody)
        
        guard let request = createRequest(endpoint: "/auth/login", method: "POST", body: body) else {
            print("❌ Failed to create login request - invalid URL")
            throw APIError.invalidURL
        }
        
        print("📡 Making login request to: \(baseURL)/auth/login")
        
        do {
            let response: AuthResponse = try await performRequest(request, responseType: AuthResponse.self)
            print("✅ Login response received successfully")
            print("   - Token: \(response.accessToken.prefix(20))...")
            print("   - User ID: \(response.user.id)")
            print("   - User Email: \(response.user.email)")
            return response
        } catch let apiError as APIError {
            print("❌ Login request failed with APIError:")
            print("   - Error: \(apiError)")
            print("   - Description: \(apiError.localizedDescription)")
            throw apiError
        } catch let decodingError as DecodingError {
            print("❌ Login request failed with DecodingError:")
            print("   - Error: \(decodingError)")
            if case .keyNotFound(let key, let context) = decodingError {
                print("   - Missing key: \(key.stringValue)")
                print("   - Context: \(context.debugDescription)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            print("❌ Login request failed: \(error)")
            print("   - Error type: \(type(of: error))")
            print("   - Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signup(username: String?, email: String, password: String, role: String = "ARTIST", accessCode: String? = nil) async throws -> AuthResponse {
        let requestBody = SignupRequest(username: username, email: email, password: password, role: role, accessCode: accessCode)
        
        // Debug: Print request details
        if let jsonData = try? JSONEncoder().encode(requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Signup Request Body: \(jsonString)")
        }
        
        let body = try JSONEncoder().encode(requestBody)
        
        guard let request = createRequest(endpoint: "/auth/signup", method: "POST", body: body) else {
            print("❌ Failed to create signup request - invalid URL")
            throw APIError.invalidURL
        }
        
        print("📡 Making signup request to: \(baseURL)/auth/signup")
        
        do {
            let response: AuthResponse = try await performRequest(request, responseType: AuthResponse.self)
            print("✅ Signup response received successfully")
            return response
        } catch {
            print("❌ Signup request failed: \(error)")
            print("   - Error type: \(type(of: error))")
            throw error
        }
    }
    
    // MARK: - OAuth Endpoints
    
    func signInWithApple(identityToken: String, email: String?, fullName: String?, role: String = "") async throws -> AuthResponse {
        // If role is empty, don't include it in the request (backend will default to ARTIST)
        var requestBody: OAuthSignInRequest
        if role.isEmpty {
            requestBody = OAuthSignInRequest(
                provider: "apple",
                identityToken: identityToken,
                email: email,
                fullName: fullName,
                role: nil
            )
        } else {
            requestBody = OAuthSignInRequest(
                provider: "apple",
                identityToken: identityToken,
                email: email,
                fullName: fullName,
                role: role
            )
        }
        
        // Debug: Print request details
        if let jsonData = try? JSONEncoder().encode(requestBody),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Request Body: \(jsonString)")
        }
        
        let body = try JSONEncoder().encode(requestBody)
        
        guard let request = createRequest(endpoint: "/auth/oauth/apple", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        print("📡 Making request to: \(baseURL)/auth/oauth/apple")
        
        do {
            let response: AuthResponse = try await performRequest(request, responseType: AuthResponse.self)
            print("✅ Response received successfully")
            return response
        } catch {
            print("❌ Request failed: \(error)")
            throw error
        }
    }
    
    func signInWithGoogle(idToken: String, email: String?, fullName: String?, role: String) async throws -> AuthResponse {
        let requestBody = OAuthSignInRequest(
            provider: "google",
            identityToken: idToken,
            email: email,
            fullName: fullName,
            role: role
        )
        let body = try JSONEncoder().encode(requestBody)
        
        guard let request = createRequest(endpoint: "/auth/oauth/google", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        let response: AuthResponse = try await performRequest(request, responseType: AuthResponse.self)
        return response
    }
    
    // MARK: - Feed Endpoint
    
    func getFeed(page: Int = 1, limit: Int = 20) async throws -> FeedResponse {
        guard let request = createRequest(endpoint: "/feed?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: FeedResponse.self)
    }
    
    // MARK: - Like Endpoints
    
    func likeTrack(trackId: String) async throws -> LikeResponse {
        let requestBody = LikeRequest(trackId: trackId)
        let body = try JSONEncoder().encode(requestBody)
        
        guard let request = createRequest(endpoint: "/like", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: LikeResponse.self)
    }
    
    func unlikeTrack(trackId: String) async throws -> LikeResponse {
        guard let request = createRequest(endpoint: "/tracks/\(trackId)/like", method: "DELETE") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: LikeResponse.self)
    }
    
    // MARK: - Comment Endpoints
    
    func getTrackComments(trackId: String, page: Int = 1, limit: Int = 20) async throws -> CommentsResponse {
        guard let request = createRequest(endpoint: "/comment/track/\(trackId)?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: CommentsResponse.self)
    }
    
    func createComment(content: String, trackId: String) async throws -> Comment {
        let requestBody = CreateCommentRequest(content: content, trackId: trackId)
        let body = try JSONEncoder().encode(requestBody)
        
        guard let request = createRequest(endpoint: "/comment", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: Comment.self)
    }
    
    // MARK: - Artist Endpoints
    
    func getAllArtists(page: Int = 1, limit: Int = 20, search: String? = nil) async throws -> ArtistsListResponse {
        var endpoint = "/artists?page=\(page)&limit=\(limit)"
        if let search = search, !search.isEmpty {
            endpoint += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        
        guard let request = createRequest(endpoint: endpoint) else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: ArtistsListResponse.self)
    }
    
    func getArtistProfile(artistId: String) async throws -> ArtistProfile {
        guard let request = createRequest(endpoint: "/artists/\(artistId)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: ArtistProfile.self)
    }
    
    func getArtistTracks(artistId: String, page: Int = 1, limit: Int = 20) async throws -> ArtistTracksResponse {
        guard let request = createRequest(endpoint: "/artists/\(artistId)/tracks?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: ArtistTracksResponse.self)
    }
    
    func followArtist(artistId: String) async throws -> FollowResponse {
        guard let request = createRequest(endpoint: "/artists/\(artistId)/follow", method: "POST") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: FollowResponse.self)
    }
    
    func unfollowArtist(artistId: String) async throws -> FollowResponse {
        guard let request = createRequest(endpoint: "/artists/\(artistId)/follow", method: "DELETE") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: FollowResponse.self)
    }
    
    func getFollowers(artistId: String, page: Int = 1, limit: Int = 20) async throws -> FollowersResponse {
        guard let request = createRequest(endpoint: "/artists/\(artistId)/followers?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: FollowersResponse.self)
    }
    
    // MARK: - Track Upload
    
    func uploadTrack(title: String, audioData: Data, fileName: String) async throws -> Track {
        guard let url = URL(string: "\(baseURL)/tracks/upload") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add title field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(title)\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request, responseType: Track.self)
    }
    
    // MARK: - Cyphers
    
    func getActiveCyphers(page: Int = 1, limit: Int = 20) async throws -> CypherResponse {
        guard let request = createRequest(endpoint: "/cyphers?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: CypherResponse.self)
    }
    
    func getCypherById(_ id: String) async throws -> CypherDetail {
        guard let request = createRequest(endpoint: "/cyphers/\(id)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: CypherDetail.self)
    }
    
    func submitCypherEntry(cypherId: String, audioData: Data, fileName: String, title: String? = nil) async throws -> CypherEntry {
        guard let url = URL(string: "\(baseURL)/cyphers/\(cypherId)/submit") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add title field if provided
        if let title = title {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(title)\r\n".data(using: .utf8)!)
        }
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request, responseType: CypherEntry.self)
    }
    
    func getCypherEntries(cypherId: String, page: Int = 1, limit: Int = 20) async throws -> CypherEntriesResponse {
        guard let request = createRequest(endpoint: "/cyphers/\(cypherId)/entries?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: CypherEntriesResponse.self)
    }
    
    func voteCypherEntry(entryId: String, bars: Int, flow: Int, creativity: Int) async throws -> VoteResponse {
        guard let url = URL(string: "\(baseURL)/cyphers/entries/\(entryId)/vote") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["bars": bars, "flow": flow, "creativity": creativity]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: VoteResponse.self)
    }
    
    func reportCypherEntry(entryId: String, reason: String) async throws {
        guard let url = URL(string: "\(baseURL)/cyphers/entries/\(entryId)/report") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["reason": reason]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    func getCypherLeaderboard(cypherId: String, limit: Int = 50) async throws -> [LeaderboardEntry] {
        guard let request = createRequest(endpoint: "/cyphers/\(cypherId)/leaderboard?limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: [LeaderboardEntry].self)
    }
    
    // MARK: - Top Cyphers
    
    func getTopCyphers(range: String = "week", limit: Int = 20) async throws -> [TopCypher] {
        guard let request = createRequest(endpoint: "/cyphers/top?range=\(range)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: [TopCypher].self)
    }
    
    // MARK: - Cypher Invites
    
    func inviteArtistToCypher(cypherId: String, artistId: String) async throws {
        guard let url = URL(string: "\(baseURL)/cyphers/\(cypherId)/invite") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = InviteArtistRequest(artistId: artistId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    func getUserCypherInvites() async throws -> [CypherInvite] {
        guard let request = createRequest(endpoint: "/cyphers/users/invites") else {
            throw APIError.invalidURL
        }
        
        do {
            return try await performRequest(request, responseType: [CypherInvite].self)
        } catch {
            // Handle 404 or auth errors gracefully - return empty array instead of throwing
            if let apiError = error as? APIError {
                if case .httpErrorWithMessage(let statusCode, _) = apiError {
                    if statusCode == 404 || statusCode == 401 || statusCode == 403 {
                        return []
                    }
                }
            }
            // For other errors, still return empty array to prevent crashes
            print("⚠️ Could not load cypher invites: \(error.localizedDescription)")
            return []
        }
    }
    
    func respondToCypherInvite(inviteId: String, response: String) async throws {
        guard let url = URL(string: "\(baseURL)/cyphers/invites/\(inviteId)/respond") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = RespondToInviteRequest(response: response)
        request.httpBody = try JSONEncoder().encode(body)
        
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    // MARK: - User Search
    
    func searchUsersByUsername(_ username: String) async throws -> [SearchUser] {
        // Require at least 2 characters to search
        guard username.count >= 2 else {
            return []
        }
        
        // Use the artists endpoint to search for users
        // The backend artists service searches by name, email, and city
        guard let encodedSearch = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let request = createRequest(endpoint: "/artists?search=\(encodedSearch)&limit=20") else {
            throw APIError.invalidURL
        }
        
        // Set a shorter timeout for search requests (10 seconds)
        var mutableRequest = request
        mutableRequest.timeoutInterval = 10.0
        
        // The artists endpoint now returns user details in the response
        struct ArtistsSearchResponse: Codable {
            let artists: [ArtistSearchResult]
            let total: Int
            let page: Int
            let limit: Int
        }
        
        struct ArtistSearchResult: Codable {
            let id: String
            let name: String
            let city: String?
            let avatarUrl: String?
            let followersCount: Int
            let tracksCount: Int
            let user: UserSearchInfo
        }
        
        struct UserSearchInfo: Codable {
            let id: String
            let email: String
            let username: String?
            let role: String
        }
        
        do {
            let response = try await performRequest(mutableRequest, responseType: ArtistsSearchResponse.self)
            
            // Filter out ADMIN accounts and map to SearchUser
            return response.artists
                .filter { artist in
                    artist.user.role.uppercased() != "ADMIN"
                }
                .map { artist in
                    SearchUser(
                        id: artist.user.id,
                        username: artist.user.username,
                        email: artist.user.email,
                        role: artist.user.role
                    )
                }
        } catch let error as APIError {
            // Handle specific API errors gracefully
            print("⚠️ User search API error: \(error.localizedDescription)")
            return []
        } catch {
            // Handle network errors and timeouts gracefully
            print("⚠️ User search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Universal Search
    
    struct UniversalSearchResponse: Codable {
        let users: [SearchUserResult]
        let cities: [String]
        let cyphers: [SearchCypherResult]
        let beats: [SearchBeatResult]
    }
    
    struct SearchUserResult: Codable, Identifiable {
        let id: String
        let username: String?
        let email: String
        let name: String
        let city: String?
        let avatarUrl: String?
        let role: String
    }
    
    struct SearchCypherResult: Codable, Identifiable {
        let id: String
        let title: String
        let description: String?
        let entryCount: Int
        let host: CypherHost?
        
        struct CypherHost: Codable {
            let id: String
            let username: String?
            let email: String
        }
    }
    
    struct SearchBeatResult: Codable, Identifiable {
        let id: String
        let title: String
        let genre: String?
        let bpm: Int
        let producer: BeatProducer?
        
        var producerName: String? {
            producer?.username ?? producer?.email
        }
        
        struct BeatProducer: Codable {
            let id: String
            let username: String?
            let email: String
        }
    }
    
    func universalSearch(query: String) async throws -> UniversalSearchResponse {
        guard query.count >= 2 else {
            return UniversalSearchResponse(users: [], cities: [], cyphers: [], beats: [])
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let request = createRequest(endpoint: "/search?q=\(encodedQuery)") else {
            throw APIError.invalidURL
        }
        
        // Set timeout for search requests
        var mutableRequest = request
        mutableRequest.timeoutInterval = 10.0
        
        do {
            return try await performRequest(mutableRequest, responseType: UniversalSearchResponse.self)
        } catch {
            print("⚠️ Universal search failed: \(error.localizedDescription)")
            // Return empty results on error instead of throwing
            return UniversalSearchResponse(users: [], cities: [], cyphers: [], beats: [])
        }
    }
    
    // MARK: - Create Cypher
    
    func createCypher(
        title: String,
        description: String?,
        beatUrl: String?,
        cypherType: String,
        startDate: Date,
        endDate: Date?
    ) async throws -> Cypher {
        guard let url = URL(string: "\(baseURL)/cyphers") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var body: [String: Any] = [
            "title": title,
            "cypherType": cypherType,
            "startDate": formatter.string(from: startDate)
        ]
        
        if let description = description {
            body["description"] = description
        }
        
        if let beatUrl = beatUrl {
            body["beatUrl"] = beatUrl
        }
        
        if let endDate = endDate {
            body["endDate"] = formatter.string(from: endDate)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: Cypher.self)
    }
    
    // MARK: - Beats API
    
    func uploadBeat(title: String, genre: String, bpm: Int, mood: String?, price: Int, audioData: Data, fileName: String) async throws -> Beat {
        guard let url = URL(string: "\(baseURL)/beats/upload") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(title)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"genre\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(genre)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"bpm\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(bpm)\r\n".data(using: .utf8)!)
        
        if let mood = mood {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mood\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(mood)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"price\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(price)\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request, responseType: Beat.self)
    }
    
    func getBeats(page: Int = 1, limit: Int = 20, genre: String? = nil, bpm: Int? = nil, mood: String? = nil) async throws -> BeatsResponse {
        var endpoint = "/beats?page=\(page)&limit=\(limit)"
        if let genre = genre {
            endpoint += "&genre=\(genre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? genre)"
        }
        if let bpm = bpm {
            endpoint += "&bpm=\(bpm)"
        }
        if let mood = mood {
            endpoint += "&mood=\(mood.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mood)"
        }
        
        guard let request = createRequest(endpoint: endpoint) else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: BeatsResponse.self)
    }
    
    func getBeatById(_ id: String) async throws -> Beat {
        guard let request = createRequest(endpoint: "/beats/\(id)") else {
            throw APIError.invalidURL
        }
        
        if let token = authToken {
            var mutableRequest = request
            mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return try await performRequest(mutableRequest, responseType: Beat.self)
        }
        
        return try await performRequest(request, responseType: Beat.self)
    }
    
    func getPreviewUrl(beatId: String) async throws -> String {
        guard let request = createRequest(endpoint: "/beats/\(beatId)/preview") else {
            throw APIError.invalidURL
        }
        
        let response = try await performRequest(request, responseType: PreviewUrlResponse.self)
        return response.previewUrl
    }
    
    func purchaseBeat(beatId: String, receipt: String) async throws -> PurchaseBeatResponse {
        guard let url = URL(string: "\(baseURL)/beats/\(beatId)/purchase") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["receipt": receipt]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(request, responseType: PurchaseBeatResponse.self)
    }
    
    func getFullBeatUrl(beatId: String) async throws -> String {
        guard let request = createRequest(endpoint: "/beats/\(beatId)/full") else {
            throw APIError.invalidURL
        }
        
        let response = try await performRequest(request, responseType: FullUrlResponse.self)
        return response.fullUrl
    }
    
    func getPurchasedBeats(page: Int = 1, limit: Int = 20) async throws -> BeatsResponse {
        guard let request = createRequest(endpoint: "/beats/purchased/my?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        
        return try await performRequest(request, responseType: BeatsResponse.self)
    }
    
    func reportBeat(beatId: String, reason: String) async throws {
        guard let url = URL(string: "\(baseURL)/beats/\(beatId)/report") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["reason": reason]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let _: [String: String] = try await performRequest(request, responseType: [String: String].self)
    }
    
    // MARK: - Subscriptions
    
    func getSubscription() async throws -> SubscriptionResponse {
        guard let request = createRequest(endpoint: "/subscriptions/me") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: SubscriptionResponse.self)
    }
    
    func subscribe(tier: String, productId: String, receipt: String, expiresAt: String?) async throws -> SubscriptionResponse {
        guard let url = URL(string: "\(baseURL)/subscriptions/subscribe") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "tier": tier,
            "productId": productId,
            "receipt": receipt
        ]
        if let expiresAt = expiresAt {
            body["expiresAt"] = expiresAt
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, responseType: SubscriptionResponse.self)
    }
    
    func cancelSubscription() async throws -> SubscriptionResponse {
        guard let url = URL(string: "\(baseURL)/subscriptions/cancel") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request, responseType: SubscriptionResponse.self)
    }
    
    // MARK: - Payouts (Producer)
    
    func getProducerEarnings() async throws -> ProducerEarningsResponse {
        guard let request = createRequest(endpoint: "/payouts/earnings") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: ProducerEarningsResponse.self)
    }
    
    func requestPayout() async throws -> PayoutResponse {
        guard let url = URL(string: "\(baseURL)/payouts/request") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request, responseType: PayoutResponse.self)
    }
    
    func getPayoutHistory() async throws -> PayoutHistoryResponse {
        guard let request = createRequest(endpoint: "/payouts/history") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: PayoutHistoryResponse.self)
    }
    
    // MARK: - User Role Update
    
    func updateUserRole(_ role: String) async throws -> AuthResponse {
        guard let request = createRequest(endpoint: "/auth/update-role", method: "POST", body: try JSONEncoder().encode(["role": role])) else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: AuthResponse.self)
    }

    func updateUsername(_ username: String) async throws -> AuthResponse {
        guard let request = createRequest(endpoint: "/auth/update-username", method: "POST", body: try JSONEncoder().encode(["username": username])) else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: AuthResponse.self)
    }

    /// Permanently deletes the signed-in user's account and data (App Store Guideline 5.1.1(v)).
    func deleteAccount() async throws -> DeleteAccountResponse {
        guard let request = createRequest(endpoint: "/auth/account", method: "DELETE") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: DeleteAccountResponse.self)
    }

    // MARK: - Articles
    
    func getArticles(page: Int = 1, limit: Int = 20) async throws -> ArticlesResponse {
        guard let request = createRequest(endpoint: "/articles?page=\(page)&limit=\(limit)") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: ArticlesResponse.self)
    }
    
    // MARK: - News (Hip-Hop News from External Sources)
    
    func getHipHopNews(query: String? = nil) async throws -> HipHopNewsResponse {
        var endpoint = "/news/hip-hop"
        if let query = query, !query.isEmpty {
            endpoint += "?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        guard let request = createRequest(endpoint: endpoint) else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, responseType: HipHopNewsResponse.self)
    }
}

// MARK: - API Errors

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case httpErrorWithMessage(Int, String)
    case decodingError(Error)
    case networkError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            if code == 400 {
                return "Invalid request. Please check your information and try again."
            } else if code == 409 {
                return "An account with this email already exists."
            } else if code == 500 {
                return "Server error. Please try again later."
            }
            return "Server error (Code: \(code)). Please try again."
        case .httpErrorWithMessage(_, let message):
            return message
        case .decodingError(_):
            return "Invalid response from server. Please try again."
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - Additional Models

struct LikeRequest: Codable {
    let trackId: String
}

struct LikeResponse: Codable {
    let message: String
    let trackId: String
}

struct DeleteAccountResponse: Codable {
    let message: String
}

struct OAuthSignInRequest: Codable {
    let provider: String // "apple" or "google"
    let identityToken: String
    let email: String?
    let fullName: String?
    let role: String? // Optional - if not provided, backend will default to ARTIST
}

