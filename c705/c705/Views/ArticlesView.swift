//
//  ArticlesView.swift
//  c705
//
//  Created for Articles tab with external API and journalist articles
//

import SwiftUI
import Combine

struct ArticlesView: View {
    @StateObject private var viewModel = ArticlesViewModel()
    @EnvironmentObject var authService: AuthService
    @Binding var searchText: String
    @State private var selectedSource = "All" // "All", "C705 Articles", "Latest News"
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Source selector
                HStack(spacing: 16) {
                    PillButton(title: "All", isSelected: selectedSource == "All") {
                        selectedSource = "All"
                        Task {
                            await viewModel.searchArticles(query: searchText, source: selectedSource)
                        }
                    }
                    PillButton(title: "C705 Articles", isSelected: selectedSource == "C705 Articles") {
                        selectedSource = "C705 Articles"
                        Task {
                            await viewModel.searchArticles(query: searchText, source: selectedSource)
                        }
                    }
                    PillButton(title: "Latest News", isSelected: selectedSource == "Latest News") {
                        selectedSource = "Latest News"
                        Task {
                            await viewModel.searchArticles(query: searchText, source: selectedSource)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Articles list
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading && viewModel.articles.isEmpty {
                        ProgressView("Loading articles...")
                            .padding()
                    } else {
                        // Show filtered articles
                        ForEach(filteredArticles) { article in
                            ArticleCardView(article: article)
                                .onTapGesture {
                                    // Open external URL in Safari if available
                                    if let url = article.externalUrl {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .transition(AppAnimations.listTransition)
                        }
                        .animation(AppAnimations.fastSpring, value: filteredArticles.count)
                    }
                }
                .padding()
            }
        }
        .refreshable {
            // Use Task.detached to prevent cancellation during refresh
            await Task.detached { @MainActor in
                await viewModel.searchArticles(query: searchText.isEmpty ? nil : searchText, source: selectedSource)
            }.value
        }
        .task {
            // Load articles on initial view
            await viewModel.searchArticles(query: searchText.isEmpty ? nil : searchText, source: selectedSource)
        }
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                await viewModel.searchArticles(query: newValue.isEmpty ? nil : newValue, source: selectedSource)
            }
        }
        .onChange(of: selectedSource) { oldValue, newValue in
            Task {
                await viewModel.searchArticles(query: searchText.isEmpty ? nil : searchText, source: newValue)
            }
        }
    }
    
    var filteredArticles: [ArticleItem] {
        let sourceFiltered: [ArticleItem]
        switch selectedSource {
        case "C705 Articles":
            sourceFiltered = viewModel.articles.filter { $0.isFromJournalist }
        case "Latest News":
            sourceFiltered = viewModel.articles.filter { !$0.isFromJournalist }
        default:
            sourceFiltered = viewModel.articles
        }
        
        // Apply search filter
        if searchText.isEmpty {
            return sourceFiltered
        }
        
        let searchLower = searchText.lowercased()
        return sourceFiltered.filter { article in
            article.title.lowercased().contains(searchLower) ||
            article.description?.lowercased().contains(searchLower) ?? false ||
            article.author.lowercased().contains(searchLower) ||
            article.city?.lowercased().contains(searchLower) ?? false
        }
    }
}

struct ArticleItem: Identifiable {
    let id: String
    let title: String
    let description: String?
    let author: String
    let publishedAt: Date
    let imageUrl: String?
    let externalUrl: URL?
    let isFromJournalist: Bool
    let city: String?
}

struct ArticleCardView: View {
    let article: ArticleItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image if available
            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(height: 200)
                .cornerRadius(12)
                .clipped()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let description = article.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                HStack {
                    Text(article.author)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let city = article.city {
                        Text("• \(city)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(article.publishedAt, style: .relative)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

@MainActor
class ArticlesViewModel: ObservableObject {
    @Published var articles: [ArticleItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func searchArticles(query: String?, source: String) async {
        isLoading = true
        errorMessage = nil
        
        // Load articles based on source
        var journalistArticles: [ArticleItem] = []
        var externalArticles: [ArticleItem] = []
        
        // Use TaskGroup to load articles concurrently
        // Wrap in Task.detached to prevent SwiftUI from cancelling during refresh
        await Task.detached { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                if source == "All" || source == "C705 Articles" {
                    group.addTask {
                        do {
                            let articles = try await self.loadJournalistArticles(query: query)
                            await MainActor.run {
                                journalistArticles = articles
                            }
                        } catch {
                            // Only log non-cancellation errors
                            if !Task.isCancelled && !(error is APIError && error.localizedDescription.contains("cancelled")) {
                                print("Error loading journalist articles: \(error)")
                            }
                        }
                    }
                }
                
                if source == "All" || source == "Latest News" {
                    group.addTask {
                        do {
                            // Always fetch latest news (last 48 hours) from backend
                            let articles = try await self.loadExternalArticles(query: query)
                            await MainActor.run {
                                externalArticles = articles
                            }
                        } catch {
                            // Only log non-cancellation errors
                            if !Task.isCancelled && !(error is APIError && error.localizedDescription.contains("cancelled")) {
                                print("Error loading external articles: \(error)")
                                await MainActor.run {
                                    self.errorMessage = "Failed to load latest news. Please try again."
                                }
                            }
                        }
                    }
                }
            }
            
            // Check if task was cancelled before updating UI
            guard !Task.isCancelled else {
                return
            }
            
            // Combine and sort by date (newest first)
            self.articles = (journalistArticles + externalArticles).sorted { $0.publishedAt > $1.publishedAt }
            self.isLoading = false
        }.value
    }
    
    private func loadJournalistArticles(query: String?) async throws -> [ArticleItem] {
        // Load articles from backend (journalist posts)
        do {
            let response = try await APIService.shared.getArticles()
            var articles = response.articles.enumerated().map { index, article in
                ArticleItem(
                    id: "jour-\(index)-\(article.id)",
                    title: article.title,
                    description: article.content,
                    author: article.author.username ?? article.author.email,
                    publishedAt: ISO8601DateFormatter().date(from: article.createdAt) ?? Date(),
                    imageUrl: nil,
                    externalUrl: nil,
                    isFromJournalist: true,
                    city: article.city
                )
            }
            
            // Filter by query if provided
            if let query = query, !query.isEmpty {
                let queryLower = query.lowercased()
                articles = articles.filter { article in
                    article.title.lowercased().contains(queryLower) ||
                    article.description?.lowercased().contains(queryLower) ?? false ||
                    article.author.lowercased().contains(queryLower) ||
                    article.city?.lowercased().contains(queryLower) ?? false
                }
            }
            
            return articles
        } catch {
            // If backend fails, return empty array (don't crash)
            print("Failed to load journalist articles: \(error)")
            return []
        }
    }
    
    private func loadExternalArticles(query: String?) async throws -> [ArticleItem] {
        // Load hip hop news from backend (which calls NewsAPI)
        // This keeps API keys secure and allows caching
        do {
            let response = try await APIService.shared.getHipHopNews(query: query)
            return response.articles.enumerated().map { index, article in
                ArticleItem(
                    id: "ext-\(index)-\(article.id)",
                    title: article.title,
                    description: article.summary,
                    author: article.author ?? article.source,
                    publishedAt: ISO8601DateFormatter().date(from: article.publishedAt) ?? Date(),
                    imageUrl: article.imageUrl,
                    externalUrl: URL(string: article.url),
                    isFromJournalist: false,
                    city: nil
                )
            }
        } catch {
            // If backend fails, return empty array (don't crash)
            print("Failed to load external articles: \(error)")
            return []
        }
    }
}

// News models moved to News.swift

#Preview {
    ArticlesView()
        .environmentObject(AuthService())
}

