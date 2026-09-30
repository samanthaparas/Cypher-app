import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

interface NewsAPIArticle {
  source: { name: string };
  author: string | null;
  title: string;
  description: string | null;
  url: string;
  urlToImage: string | null;
  publishedAt: string;
  content: string | null;
}

interface NewsAPIResponse {
  status: string;
  totalResults: number;
  articles: NewsAPIArticle[];
}

interface GNewsArticle {
  title: string;
  description: string;
  content: string;
  url: string;
  image: string | null;
  publishedAt: string;
  source: { name: string; url: string };
}

interface GNewsResponse {
  totalArticles: number;
  articles: GNewsArticle[];
}

export interface CleanedArticle {
  id: string;
  title: string;
  summary: string;
  source: string;
  url: string;
  imageUrl: string | null;
  publishedAt: string;
  author: string | null;
}

@Injectable()
export class NewsService {
  private readonly logger = new Logger(NewsService.name);
  private cache: {
    articles: CleanedArticle[];
    timestamp: number;
  } | null = null;
  private readonly CACHE_DURATION = 30 * 60 * 1000; // 30 minutes
  private readonly HOURS_48_AGO = 48 * 60 * 60 * 1000; // 48 hours in milliseconds

  constructor(private readonly httpService: HttpService) {}

  /**
   * Fetch hip-hop news from NewsAPI and GNews
   * Cached for 30 minutes to avoid rate limits
   * Only returns articles from the last 48 hours
   */
  async getHipHopNews(query?: string): Promise<CleanedArticle[]> {
    // Check cache first
    if (this.cache && Date.now() - this.cache.timestamp < this.CACHE_DURATION) {
      this.logger.log('Returning cached news articles');
      const filtered = this.filterBy48Hours(this.cache.articles);
      return this.filterArticles(filtered, query);
    }

    const allArticles: CleanedArticle[] = [];
    const cutoffTime = Date.now() - this.HOURS_48_AGO;

    // Try NewsAPI first
    try {
      const newsApiArticles = await this.fetchFromNewsAPI(query);
      allArticles.push(...newsApiArticles);
      this.logger.log(`Fetched ${newsApiArticles.length} articles from NewsAPI`);
    } catch (error) {
      this.logger.warn('NewsAPI fetch failed, trying GNews:', error.message);
    }

    // Try GNews as fallback or supplement
    try {
      const gNewsArticles = await this.fetchFromGNews(query);
      allArticles.push(...gNewsArticles);
      this.logger.log(`Fetched ${gNewsArticles.length} articles from GNews`);
    } catch (error) {
      this.logger.warn('GNews fetch failed:', error.message);
    }

    // Remove duplicates by URL
    const uniqueArticles = this.removeDuplicates(allArticles);

    // Filter to last 48 hours
    const recentArticles = this.filterBy48Hours(uniqueArticles);

    // Sort by published date (newest first)
    recentArticles.sort((a, b) => {
      const dateA = new Date(a.publishedAt).getTime();
      const dateB = new Date(b.publishedAt).getTime();
      return dateB - dateA;
    });

    // Cache the results
    this.cache = {
      articles: recentArticles,
      timestamp: Date.now(),
    };

    return this.filterArticles(recentArticles, query);
  }

  /**
   * Fetch articles from NewsAPI
   */
  private async fetchFromNewsAPI(query?: string): Promise<CleanedArticle[]> {
    const apiKey = process.env.NEWS_API_KEY;
    if (!apiKey || apiKey === 'YOUR_NEWS_API_KEY') {
      throw new Error('NewsAPI key not configured');
    }

    // Calculate date 48 hours ago
    const fromDate = new Date(Date.now() - this.HOURS_48_AGO);
    const fromDateStr = fromDate.toISOString().split('T')[0]; // YYYY-MM-DD format

    // Build search query
    let searchQuery = 'hip hop OR rap OR hiphop OR rap music';
    if (query && query.trim()) {
      searchQuery = `${query.trim()} AND (hip hop OR rap OR hiphop)`;
    }

    const url = `https://newsapi.org/v2/everything?q=${encodeURIComponent(searchQuery)}&from=${fromDateStr}&sortBy=publishedAt&language=en&pageSize=50&apiKey=${apiKey}`;

    this.logger.log(`Fetching from NewsAPI: ${searchQuery}`);

    const response = await firstValueFrom(
      this.httpService.get<NewsAPIResponse>(url, {
        timeout: 10000, // 10 second timeout
      }),
    );

    if (response.data.status !== 'ok') {
      throw new Error(`NewsAPI returned status: ${response.data.status}`);
    }

    return this.cleanNewsAPIArticles(response.data.articles);
  }

  /**
   * Fetch articles from GNews API
   */
  private async fetchFromGNews(query?: string): Promise<CleanedArticle[]> {
    const apiKey = process.env.GNEWS_API_KEY;
    if (!apiKey || apiKey === 'YOUR_GNEWS_API_KEY') {
      throw new Error('GNews API key not configured');
    }

    // Build search query
    let searchQuery = 'hip hop OR rap OR hiphop';
    if (query && query.trim()) {
      searchQuery = `${query.trim()} (hip hop OR rap OR hiphop)`;
    }

    // GNews uses "from" parameter for date filtering (last 48 hours)
    const fromDate = new Date(Date.now() - this.HOURS_48_AGO);
    const fromDateStr = fromDate.toISOString().split('T')[0]; // YYYY-MM-DD format

    const url = `https://gnews.io/api/v4/search?q=${encodeURIComponent(searchQuery)}&lang=en&max=50&from=${fromDateStr}&apikey=${apiKey}`;

    this.logger.log(`Fetching from GNews: ${searchQuery}`);

    const response = await firstValueFrom(
      this.httpService.get<GNewsResponse>(url, {
        timeout: 10000, // 10 second timeout
      }),
    );

    return this.cleanGNewsArticles(response.data.articles);
  }

  /**
   * Clean and normalize articles from NewsAPI
   * Only keep what we need - no full content storage
   */
  private cleanNewsAPIArticles(articles: NewsAPIArticle[]): CleanedArticle[] {
    return articles
      .filter((article) => {
        // Filter out articles without title or URL
        return article.title && article.url;
      })
      .map((article) => ({
        id: this.generateId(article.url),
        title: article.title,
        summary: article.description || this.truncateContent(article.content) || '',
        source: article.source.name,
        url: article.url,
        imageUrl: article.urlToImage || null,
        publishedAt: article.publishedAt,
        author: article.author || null,
      }));
  }

  /**
   * Clean and normalize articles from GNews
   */
  private cleanGNewsArticles(articles: GNewsArticle[]): CleanedArticle[] {
    return articles
      .filter((article) => {
        // Filter out articles without title or URL
        return article.title && article.url;
      })
      .map((article) => ({
        id: this.generateId(article.url),
        title: article.title,
        summary: article.description || this.truncateContent(article.content) || '',
        source: article.source.name,
        url: article.url,
        imageUrl: article.image || null,
        publishedAt: article.publishedAt,
        author: null, // GNews doesn't always provide author
      }));
  }

  /**
   * Filter articles to only include those from the last 48 hours
   */
  private filterBy48Hours(articles: CleanedArticle[]): CleanedArticle[] {
    const cutoffTime = Date.now() - this.HOURS_48_AGO;
    
    return articles.filter((article) => {
      try {
        const publishedTime = new Date(article.publishedAt).getTime();
        return publishedTime >= cutoffTime;
      } catch (error) {
        // If date parsing fails, exclude the article
        return false;
      }
    });
  }

  /**
   * Remove duplicate articles by URL
   */
  private removeDuplicates(articles: CleanedArticle[]): CleanedArticle[] {
    const seenUrls = new Set<string>();
    return articles.filter((article) => {
      const normalizedUrl = article.url.toLowerCase().trim();
      if (seenUrls.has(normalizedUrl)) {
        return false;
      }
      seenUrls.add(normalizedUrl);
      return true;
    });
  }

  /**
   * Filter articles by query (client-side filtering for cached results)
   */
  private filterArticles(
    articles: CleanedArticle[],
    query?: string,
  ): CleanedArticle[] {
    if (!query || !query.trim()) {
      return articles;
    }

    const queryLower = query.toLowerCase();
    return articles.filter(
      (article) =>
        article.title.toLowerCase().includes(queryLower) ||
        article.summary.toLowerCase().includes(queryLower) ||
        article.source.toLowerCase().includes(queryLower) ||
        (article.author && article.author.toLowerCase().includes(queryLower)),
    );
  }

  /**
   * Generate a simple ID from URL
   */
  private generateId(url: string): string {
    // Use a hash of the URL as ID
    return Buffer.from(url).toString('base64').slice(0, 32);
  }

  /**
   * Truncate content to summary length
   */
  private truncateContent(content: string | null): string | null {
    if (!content) return null;
    // Remove [+XXX chars] pattern from NewsAPI
    const cleaned = content.replace(/\[\+\d+\s*chars\]/gi, '').trim();
    return cleaned.length > 200 ? cleaned.slice(0, 200) + '...' : cleaned;
  }

  /**
   * Clear cache (useful for testing or manual refresh)
   */
  clearCache() {
    this.cache = null;
    this.logger.log('News cache cleared');
  }
}

