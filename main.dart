import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// ---------------- Model ----------------
class Article {
  final int id;
  final String title, body;
  Article({required this.id, required this.title, required this.body});

  factory Article.fromJson(Map<String, dynamic> j) =>
      Article(id: j['id'], title: j['title'], body: j['body']);
}

// ---------------- Service (REST API) ----------------
class NewsService {
  Future<List<Article>> fetchArticles() async {
    final res = await http
        .get(Uri.parse('https://jsonplaceholder.typicode.com/posts'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Server error: ${res.statusCode}');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => Article.fromJson(e)).toList();
  }
}

// ---------------- Provider (business logic) ----------------
enum Status { loading, success, error }

class NewsProvider extends ChangeNotifier {
  final NewsService _service = NewsService();

  Status status = Status.loading;
  String errorMessage = '';
  List<Article> _articles = [];
  final Set<int> _favorites = {};
  String _query = '';

  List<Article> get filtered => _query.isEmpty
      ? _articles
      : _articles
            .where((a) => a.title.toLowerCase().contains(_query.toLowerCase()))
            .toList();

  int get favoritesCount => _favorites.length;
  bool isFavorite(int id) => _favorites.contains(id);

  Future<void> load() async {
    status = Status.loading;
    notifyListeners();
    try {
      _articles = await _service.fetchArticles();
      status = Status.success;
    } catch (e) {
      errorMessage = e.toString();
      status = Status.error;
    }
    notifyListeners();
  }

  void search(String q) {
    _query = q;
    notifyListeners();
  }

  void toggleFavorite(int id) {
    _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    notifyListeners();
  }
}

// ---------------- App ----------------
void main() => runApp(
  ChangeNotifierProvider(
    create: (_) => NewsProvider()..load(),
    child: const NewsApp(),
  ),
);

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'News Reader',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: const NewsListScreen(),
  );
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
          Expanded(child: _body(context, p)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, NewsProvider p) {
    switch (p.status) {
      case Status.loading:
        return const Center(child: CircularProgressIndicator());
      case Status.error:
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
      case Status.success:
        final list = p.filtered;
        if (list.isEmpty) return const Center(child: Text('No articles found'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final a = list[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${a.id}')),
              title: Text(
                a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                a.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: Icon(
                  p.isFavorite(a.id) ? Icons.favorite : Icons.favorite_border,
                  color: p.isFavorite(a.id) ? Colors.red : null,
                ),
                onPressed: () => p.toggleFavorite(a.id),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArticleDetailScreen(article: a),
                ),
              ),
            );
          },
        );
    }
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
