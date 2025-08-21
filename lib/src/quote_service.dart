import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../quotes.dart';
import 'categories.dart';

class Quote {
  final String content;
  final String author;
  final String source; // "ZenQuotes" | "Quotable" | "Local"
  const Quote(this.content, this.author, this.source);
}

class QuoteService {
  final _rng = Random();
  final Map<String, List<Quote>> _poolByKey = {};

  // Simple global cooldown to avoid rapid-fire 429
  DateTime _nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _minInterval = const Duration(seconds: 2);

  Future<Quote> next(Category? category) async {
    final now = DateTime.now();
    if (now.isBefore(_nextAllowed)) {
      throw Cooldown(_nextAllowed.difference(now));
    }
    _nextAllowed = now.add(_minInterval);

    final key = category?.name ?? '_general';
    final pool = _poolByKey.putIfAbsent(key, () => []);

    if (pool.isNotEmpty) return pool.removeAt(0);

    // Refill order:
    // - General: ZenQuotes (50)
    // - Category: Quotable random with tags (30)
    try {
      if (category == null) {
        await _refillFromZenQuotes(pool);
      } else {
        await _refillFromQuotable(category, pool);
      }
    } catch (_) {
      // ignore; we have local fallback below
    }

    if (pool.isNotEmpty) return pool.removeAt(0);

    // Local fallback (filtered by category keywords)
    return localQuote(category);
  }

  Quote localQuote(Category? category) {
    if (category == null) {
      final m = localQuotes[_rng.nextInt(localQuotes.length)];
      return Quote(m['text'] ?? '',
          (m['author']?.isEmpty ?? true) ? 'Unknown' : m['author']!, 'Local');
    }

    final hits = <Map<String, String>>[];
    final keys = category.keywords.map((e) => e.toLowerCase()).toList();
    for (final m in localQuotes) {
      final text = (m['text'] ?? '').toLowerCase();
      if (keys.any((k) => text.contains(k))) {
        hits.add(m);
      }
    }
    if (hits.isEmpty) {
      final m = localQuotes[_rng.nextInt(localQuotes.length)];
      return Quote(m['text'] ?? '',
          (m['author']?.isEmpty ?? true) ? 'Unknown' : m['author']!, 'Local');
    }
    final pick = hits[_rng.nextInt(hits.length)];
    return Quote(pick['text'] ?? '',
        (pick['author']?.isEmpty ?? true) ? 'Unknown' : pick['author']!, 'Local');
  }

  Future<void> _refillFromZenQuotes(List<Quote> pool) async {
    final res = await http
        .get(Uri.parse('https://zenquotes.io/api/quotes'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 429) throw Exception('rate-limited');
    if (res.statusCode != 200) throw Exception('server ${res.statusCode}');
    final list = jsonDecode(res.body) as List<dynamic>;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final q = (m['q'] ?? '').toString().trim();
      if (q.isEmpty) continue;
      final a = (m['a'] ?? 'Unknown').toString().trim();
      pool.add(Quote(q, a.isEmpty ? 'Unknown' : a, 'ZenQuotes'));
    }
  }

  Future<void> _refillFromQuotable(Category category, List<Quote> pool) async {
    final tagsParam = category.tags.join('|'); // OR
    final res = await http
        .get(Uri.parse(
            'https://api.quotable.io/quotes/random?limit=30&tags=$tagsParam'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('server ${res.statusCode}');
    final list = jsonDecode(res.body) as List<dynamic>;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final q = (m['content'] ?? '').toString().trim();
      if (q.isEmpty) continue;
      final a = (m['author'] ?? 'Unknown').toString().trim();
      pool.add(Quote(q, a.isEmpty ? 'Unknown' : a, 'Quotable'));
    }
  }
}

class Cooldown implements Exception {
  final Duration remaining;
  Cooldown(this.remaining);
}
