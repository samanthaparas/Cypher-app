//
//  CypherHubView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//

import SwiftUI
import CoreLocation
import Combine
import MapKit

struct CypherHubView: View {
    @ObservedObject var viewModel: CypherHubViewModel
    @State private var selectedCypherId: String?
    @State private var selectedInvite: CypherInvite?
    @State private var searchText = ""
    @State private var selectedTab = "Top"
    @State private var showCreateCypher = false
    @StateObject private var locationManager = LocationManager()
    @State private var topCypherAnnouncement: TopCypherAnnouncement?
    @State private var announcementUpdateTimer: Timer?
    @State private var hasLoadedInitially = false
    
    let tabs = ["Top", "All"]
    
    struct TopCypherAnnouncement {
        let username: String
        let city: String
        let cypherTitle: String
        let cypherId: String
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                    
                    TextField("Search cyphers...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 10)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Category Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(tabs, id: \.self) { tab in
                            VStack(spacing: 4) {
                                Text(tab)
                                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .regular))
                                    .foregroundColor(selectedTab == tab ? .primary : .gray)
                                
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(height: 2)
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Create Cypher Button
                Button(action: {
                    showCreateCypher = true
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Create Cypher")
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(18)
                }
                .padding(.horizontal)
                
                // Dynamic Notification Banner
                if let announcement = topCypherAnnouncement {
                    Button(action: {
                        selectedCypherId = announcement.cypherId
                    }) {
                        HStack {
                            Text("\(announcement.username) is dominating the \(announcement.city) Cypher! Check it out 🔥🔥🔥")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding()
                        .background(Color(red: 0.98, green: 0.96, blue: 0.92))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                } else if viewModel.isLoading {
                    // Placeholder only while a request is actually in flight
                    HStack {
                        Text("Loading top cypher...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                    .background(Color(red: 0.98, green: 0.96, blue: 0.92))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    // Loaded, but nothing to announce yet
                    HStack {
                        Text("No top cypher yet. Start one!")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                    .background(Color(red: 0.98, green: 0.96, blue: 0.92))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                if viewModel.isLoading && viewModel.topCyphers.isEmpty {
                    ProgressView("Loading cyphers...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    // Popular Cyphers Section
                    if !viewModel.topCyphers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Popular Cyphers")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                Spacer()
                                Button(action: {
                                    // TODO: Navigate to view all
                                    print("View All")
                                }) {
                                    Text("View All >")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(Array(viewModel.topCyphers.prefix(3).enumerated()), id: \.element.id) { index, cypher in
                                    PopularCypherCardView(
                                        cypher: cypher,
                                        rank: index + 1,
                                        onTap: {
                                            selectedCypherId = cypher.id
                                        },
                                        onJoin: {
                                            selectedCypherId = cypher.id
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Cypher")
        .refreshable {
            // Allow refresh to reload cyphers
            await viewModel.loadCyphers()
            // Only update announcement if we have cyphers
            if !viewModel.topCyphers.isEmpty || !viewModel.trendingCyphers.isEmpty {
                await updateTopCypherAnnouncement()
            }
        }
        .sheet(item: $selectedInvite) { invite in
            CypherInviteDetailView(invite: invite, viewModel: viewModel)
        }
        .fullScreenCover(item: Binding(
            get: { selectedCypherId.map { CypherNavigation(id: $0) } },
            set: { selectedCypherId = $0?.id }
        )) { nav in
            CypherDetailView(cypherId: nav.id)
        }
        .sheet(isPresented: $showCreateCypher) {
            CreateCypherView()
        }
        .task {
            // Only load once when view first appears if we don't have data and haven't loaded yet
            guard !hasLoadedInitially else { return }
            guard viewModel.topCyphers.isEmpty && viewModel.trendingCyphers.isEmpty && !viewModel.isLoading else {
                hasLoadedInitially = true
                return
            }
            
            hasLoadedInitially = true
            await viewModel.loadCyphers()
            await updateTopCypherAnnouncement()
        }
        .onAppear {
            // Only set up timer if it doesn't already exist
            if announcementUpdateTimer == nil {
                // Set up timer to update every 60 seconds (reduced frequency to prevent network issues)
                announcementUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                    Task { @MainActor in
                        // Only update announcement if we have cyphers loaded
                        if !viewModel.topCyphers.isEmpty || !viewModel.trendingCyphers.isEmpty {
                            await updateTopCypherAnnouncement()
                        }
                    }
                }
            }
        }
        .onDisappear {
            announcementUpdateTimer?.invalidate()
        }
    }
    
    // MARK: - Top Cypher Announcement Logic
    
    private func updateTopCypherAnnouncement() async {
        // Only update if we have cyphers loaded
        // Don't recursively call loadCyphers - let refreshable handle that
        guard !viewModel.topCyphers.isEmpty || !viewModel.trendingCyphers.isEmpty else {
            // If no cyphers, just return - user can pull to refresh
            await MainActor.run {
                topCypherAnnouncement = nil
            }
            return
        }
        
        // Get user's current city from location (with short timeout to prevent hanging)
        let userCity = await withTimeout(seconds: 1.5, operation: {
            await locationManager.getCurrentCity()
        }) ?? ""
        
        // Get all cyphers and find the top one based on engagement
        let allCyphers = viewModel.topCyphers + viewModel.trendingCyphers
        
        guard !allCyphers.isEmpty else {
            await MainActor.run {
                topCypherAnnouncement = nil
            }
            return
        }
        
        // Filter by city if we have location, otherwise use all
        let cityCyphers: [TopCypher]
        if userCity.isEmpty {
            cityCyphers = allCyphers
        } else {
            cityCyphers = allCyphers.filter { cypher in
                let description = cypher.description ?? ""
                let searchText = description + " " + cypher.title
                return searchText.localizedCaseInsensitiveContains(userCity)
            }
        }
        
        // Helper function to calculate engagement
        func calculateEngagement(_ cypher: TopCypher) -> Int {
            return cypher.entryCount + cypher.voteCount
        }
        
        // Find cypher with highest combined engagement (entryCount + voteCount)
        let topCypher = cityCyphers.max { cypher1, cypher2 in
            let engagement1 = calculateEngagement(cypher1)
            let engagement2 = calculateEngagement(cypher2)
            return engagement1 < engagement2
        }
        
        // If no city-specific cypher, use overall top
        let finalCypher: TopCypher?
        if let top = topCypher {
            finalCypher = top
        } else {
            finalCypher = allCyphers.max { cypher1, cypher2 in
                let engagement1 = calculateEngagement(cypher1)
                let engagement2 = calculateEngagement(cypher2)
                return engagement1 < engagement2
            }
        }
        
        guard let cypher = finalCypher else {
            await MainActor.run {
                topCypherAnnouncement = nil
            }
            return
        }
        
        // Get the top entry user (user with most votes in this cypher)
        // Use host username to avoid additional API calls that cause 404 errors
        let topUsername = cypher.host.username ?? cypher.host.email.components(separatedBy: "@").first?.capitalized ?? "Someone"
        
        // Determine city from cypher or use user's city
        let city = extractCity(from: cypher) ?? (userCity.isEmpty ? "Local" : userCity)
        
        await MainActor.run {
            topCypherAnnouncement = TopCypherAnnouncement(
                username: topUsername,
                city: city,
                cypherTitle: cypher.title,
                cypherId: cypher.id
            )
        }
    }
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            group.addTask {
                return await operation()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            
            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }
    
    private func extractCity(from cypher: TopCypher) -> String? {
        let searchText = (cypher.description ?? "") + " " + cypher.title
        
        // Common cities to check
        let cities = ["Baltimore", "Philadelphia", "New York", "NYC", "Los Angeles", "LA", "Chicago", "Houston", "Phoenix", "Miami", "Atlanta", "Detroit", "Boston", "Seattle", "Dallas", "San Francisco"]
        
        for city in cities {
            if searchText.localizedCaseInsensitiveContains(city) {
                // Normalize city names
                if city == "NYC" || city == "New York" {
                    return "New York"
                } else if city == "LA" || city == "Los Angeles" {
                    return "Los Angeles"
                } else if city == "San Francisco" {
                    return "San Francisco"
                }
                return city
            }
        }
        
        return nil
    }
}

// Helper struct for navigation
struct CypherNavigation: Identifiable {
    let id: String
}

// Popular Cypher Card View matching the design
struct PopularCypherCardView: View {
    let cypher: TopCypher
    let rank: Int
    let onTap: () -> Void
    let onJoin: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Image
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            // Cypher Info
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(rank) \(cypher.title)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Text(cypher.host.username ?? cypher.host.email)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                // Beat type and city
                Text("\(beatTypeDisplay) | 📍 \(cityDisplay)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                // Entries and votes
                HStack(spacing: 12) {
                    Label("\(cypher.entryCount) entries", systemImage: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Label("\(formatVotes(cypher.voteCount)) votes", systemImage: "hand.thumbsup.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Join Cypher Button
            Button(action: onJoin) {
                Text("Join Cypher")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
    }
    
    private var beatTypeDisplay: String {
        // Extract beat type from description or use default
        // In production, you'd have a beat type field in the model
        if let description = cypher.description {
            if description.lowercased().contains("chill") {
                return "Chill Trap Beat"
            } else if description.lowercased().contains("dark") {
                return "Dark Trap Beat"
            }
        }
        return "Dark Trap Beat" // Default
    }
    
    private var cityDisplay: String {
        // Extract city from description or use default
        // In production, you'd have a city field in the model
        if let description = cypher.description {
            // Try to extract city from description
            if description.contains("Baltimore") {
                return "Baltimore"
            } else if description.contains("Philadelphia") || description.contains("Philly") {
                return "Philadelphia"
            } else if description.contains("New York") || description.contains("NYC") {
                return "New York City"
            }
        }
        return "Baltimore" // Default
    }
    
    private func formatVotes(_ votes: Int) -> String {
        if votes >= 1000 {
            return String(format: "%.1fK", Double(votes) / 1000.0)
        }
        return "\(votes)"
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentCity: String = ""
    private var geocodingTask: Task<Void, Never>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        reverseGeocode(location: location)
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Set a default city if location fails; avoid console noise for denied/unavailable
        DispatchQueue.main.async {
            self.currentCity = ""
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        // Cancel any pending geocoding tasks
        geocodingTask?.cancel()
        
        // Only geocode if we don't already have a city
        guard currentCity.isEmpty else { return }
        
        // Use MapKit for reverse geocoding (iOS 26+ compatible)
        geocodingTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Use MapKit for reverse geocoding (iOS 26+ compatible)
                let coordinate = location.coordinate
                
                // Strategy: Use MKLocalSearch to find nearby addresses/places
                // and extract city information using the new address API
                let request = MKLocalSearch.Request()
                request.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                
                // Search for nearby addresses to get location context
                request.naturalLanguageQuery = "address"
                request.resultTypes = [.address]
                
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                // Try to extract city from any result using MapKit's new API
                // Since placemark.locality is deprecated, we use alternative methods
                for mapItem in response.mapItems {
                    // Method 1: Use the mapItem's name which often contains city information
                    if let name = mapItem.name {
                        // Try to extract city from name (format might be "Place, City, State")
                        let components = name.components(separatedBy: ",")
                        if components.count >= 2 {
                            let possibleCity = components[1].trimmingCharacters(in: .whitespaces)
                            if !possibleCity.isEmpty && possibleCity.count < 50 { // Reasonable city name length
                                await MainActor.run {
                                    if self.currentCity.isEmpty {
                                        self.currentCity = possibleCity
                                    }
                                }
                                return
                            }
                        }
                    }
                    
                    // Method 2: Use the location property to search for nearby city info
                    let location = mapItem.location
                    // Create a new search centered on this location to find city
                    let cityRequest = MKLocalSearch.Request()
                    cityRequest.region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                    cityRequest.naturalLanguageQuery = "city"
                    cityRequest.resultTypes = [.address]
                    
                    if let citySearch = try? await MKLocalSearch(request: cityRequest).start(),
                       let firstResult = citySearch.mapItems.first,
                       let resultName = firstResult.name {
                        // Extract city name from the result name
                        let cityName = resultName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if !cityName.isEmpty {
                            await MainActor.run {
                                if self.currentCity.isEmpty {
                                    self.currentCity = cityName
                                }
                            }
                            return
                        }
                    }
                }
                
                // If no city found, try searching for points of interest
                let poiRequest = MKLocalSearch.Request()
                poiRequest.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
                poiRequest.naturalLanguageQuery = "restaurant"
                poiRequest.resultTypes = [.pointOfInterest]
                
                let poiSearch = MKLocalSearch(request: poiRequest)
                let poiResponse = try await poiSearch.start()
                
                for mapItem in poiResponse.mapItems {
                    // Try extracting from name first
                    if let name = mapItem.name {
                        let components = name.components(separatedBy: ",")
                        if components.count >= 2 {
                            let possibleCity = components[1].trimmingCharacters(in: .whitespaces)
                            if !possibleCity.isEmpty && possibleCity.count < 50 {
                                await MainActor.run {
                                    if self.currentCity.isEmpty {
                                        self.currentCity = possibleCity
                                    }
                                }
                                return
                            }
                        }
                    }
                    
                    // Use location to search for city
                    let location = mapItem.location
                    let cityRequest = MKLocalSearch.Request()
                    cityRequest.region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                    cityRequest.naturalLanguageQuery = "city"
                    cityRequest.resultTypes = [.address]
                    
                    if let citySearch = try? await MKLocalSearch(request: cityRequest).start(),
                       let firstResult = citySearch.mapItems.first,
                       let resultName = firstResult.name {
                        let cityName = resultName.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
                        if !cityName.isEmpty {
                            await MainActor.run {
                                if self.currentCity.isEmpty {
                                    self.currentCity = cityName
                                }
                            }
                            return
                        }
                    }
                }
            } catch {
                // If MapKit search fails, silently fail - location services may not be available
                // Do not log; MKError 4 (placemarkNotFound) and network errors are common
            }
        }
    }
    
    func getCurrentCity() async -> String {
        // Return immediately if we already have the city
        if !currentCity.isEmpty {
            return currentCity
        }
        
        // Request location if we don't have it and have permission
        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            // Only request if we're not already updating and don't have location
            if let existingLocation = locationManager.location {
                // If we have location but no city, try to geocode
                reverseGeocode(location: existingLocation)
            } else {
                // Request new location (this is async, don't wait too long)
                locationManager.requestLocation()
                
                // Wait a short time for location to update (with timeout)
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds max
                    
                    // If we got location, try to geocode
                    if let location = locationManager.location {
                        reverseGeocode(location: location)
                        // Wait a bit more for geocoding
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    }
                } catch {
                    // Task was cancelled or timed out - return empty
                    return currentCity
                }
            }
        }
        
        return currentCity
    }
}

// Legacy card view kept for compatibility
struct CypherCardView: View {
    let cypher: Cypher
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cypher.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                        
                        if let description = cypher.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Type Badge
                    Text(cypher.cypherType.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor)
                        .cornerRadius(8)
                }
                
                HStack {
                    Label("\(cypher.entryCount ?? 0) entries", systemImage: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if let endDate = cypher.endDate {
                        Label(timeRemaining(endDate), systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var typeColor: Color {
        switch cypher.cypherType {
        case .open:
            return .blue
        case .competitive:
            return .orange
        case .beatLocked:
            return .purple
        }
    }
    
    func timeRemaining(_ endDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: endDate) else {
            return "Ended"
        }
        
        let timeInterval = date.timeIntervalSinceNow
        if timeInterval <= 0 {
            return "Ended"
        }
        
        let days = Int(timeInterval / 86400)
        let hours = Int((timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days > 0 {
            return "\(days)d \(hours)h left"
        } else {
            return "\(hours)h left"
        }
    }
}
