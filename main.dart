import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// ---------------- Model ----------------
class Article {
  final int id;
  final String title;
  final String body;

  Article({required this.id, required this.title, required this.body});

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

// ---------------- Service (REST API) ----------------
class NewsService {
  Future<List<Article>> fetchArticles() async {
    final response = await http
        .get(Uri.parse('https://jsonplaceholder.typicode.com/posts'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------------- Provider (business logic) ----------------
enum LoadStatus { loading, success, error }

class NewsProvider extends ChangeNotifier {
  final NewsService _service = NewsService();

  LoadStatus status = LoadStatus.loading;
  String errorMessage = '';
  List<Article> _articles = [];
  final Set<int> _favorites = {};
  String _query = '';

  List<Article> get filtered {
    if (_query.isEmpty) return _articles;
    return _articles
        .where((a) => a.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  int get favoritesCount => _favorites.length;

  bool isFavorite(int id) => _favorites.contains(id);

  Future<void> load() async {
    status = LoadStatus.loading;
    notifyListeners();
    try {
      _articles = await _service.fetchArticles();
      status = LoadStatus.success;
    } catch (e) {
      errorMessage = 'Failed to load articles.\n$e';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  void search(String q) {
    _query = q;
    notifyListeners();
  }

  void toggleFavorite(int id) {
    if (_favorites.contains(id)) {
      _favorites.remove(id);
    } else {
      _favorites.add(id);
    }
    notifyListeners();
  }
}

// ---------------- App ----------------
void main() {
  runApp(
    ChangeNotifierProvider<NewsProvider>(
      create: (_) => NewsProvider()..load(),
      child: const NewsApp(),
    ),
  );
}

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'News Reader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const NewsListScreen(),
    );
  }
}

// ---------------- List screen ----------------
class NewsListScreen extends StatelessWidget {
  const NewsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NewsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('News Reader'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  '${p.favoritesCount}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: p.search,
              decoration: InputDecoration(
                hintText: 'Search by title...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(child: _buildContent(context, p)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, NewsProvider p) {
    if (p.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (p.status == LoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(p.errorMessage, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: p.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final list = p.filtered;
    if (list.isEmpty) {
      return const Center(child: Text('No articles found'));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final a = list[i];
        final fav = p.isFavorite(a.id);
        return ListTile(
          leading: CircleAvatar(child: Text('${a.id}')),
          title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(a.body, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? Colors.red : null,
            ),
            onPressed: () => p.toggleFavorite(a.id),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArticleDetailScreen(article: a),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- Detail screen ----------------
class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NewsProvider>();
    final fav = p.isFavorite(article.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Article #${article.id}'),
        actions: [
          IconButton(
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? Colors.red : null,
            ),
            onPressed: () => p.toggleFavorite(article.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(article.body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
