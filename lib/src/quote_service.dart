import 'dart:async';
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
  final Map<String, Future<void>> _ongoingFetch = {};

  // Simple global cooldown to avoid rapid-fire 429
  DateTime _nextAllowed = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _minInterval = const Duration(seconds: 2);

  Future<Quote> next(Category? category) async {
    final key = category?.name ?? '_general';
    final pool = _poolByKey.putIfAbsent(key, () => []);

    if (pool.isNotEmpty) {
      final quote = pool.removeAt(0);
      unawaited(_ensurePrefetch(key, category, pool, desired: 5, awaitCompletion: false));
      return quote;
    }

    await _ensurePrefetch(key, category, pool, desired: 1, awaitCompletion: true);

    if (pool.isNotEmpty) {
      final quote = pool.removeAt(0);
      unawaited(_ensurePrefetch(key, category, pool, desired: 5, awaitCompletion: false));
      return quote;
    }

    // Local fallback (filtered by category keywords)
    return localQuote(category);
  }

  Future<void> prefetch(Category? category, {int desired = 10}) async {
    final key = category?.name ?? '_general';
    final pool = _poolByKey.putIfAbsent(key, () => []);
    await _ensurePrefetch(key, category, pool,
        desired: desired, awaitCompletion: true);
  }

  Future<void> _ensurePrefetch(String key, Category? category, List<Quote> pool,
      {required int desired, required bool awaitCompletion}) async {
    if (pool.length >= desired) return;

    final inFlight = _ongoingFetch[key];
    if (inFlight != null) {
      if (awaitCompletion) await inFlight;
      return;
    }

    final future = _fetchMore(category, pool);
    _ongoingFetch[key] = future;
    future.whenComplete(() {
      if (identical(_ongoingFetch[key], future)) {
        _ongoingFetch.remove(key);
      }
    });

    if (awaitCompletion) {
      await future;
    }
  }

  Future<void> _fetchMore(Category? category, List<Quote> pool) async {
    final wait = _nextAllowed.difference(DateTime.now());
    if (wait > Duration.zero) {
      await Future.delayed(wait);
    }
    _nextAllowed = DateTime.now().add(_minInterval);

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
      // ignore; we have local fallback
    }
  }

  Quote localQuote(Category? category) {
    final picks = localQuotesForCategory(category, limit: 1);
    if (picks.isEmpty) {
      return const Quote('No offline quotes available yet.', 'Unknown', 'Local');
    }
    return picks.first;
  }

  List<Quote> localQuotesForCategory(Category? category, {int limit = 30}) {
    final entries = List<Map<String, String>>.of(_localEntriesFor(category));
    if (entries.isEmpty) return const [];
    entries.shuffle(_rng);
    final slice = entries.take(limit).map(_mapToQuote).toList();
    return slice;
  }

  List<Quote> searchLocalQuotes(String query,
      {Category? category, int limit = 60}) {
    final search = query.trim().toLowerCase();
    if (search.isEmpty) return const [];
    final entries = _localEntriesFor(category);
    final results = <Quote>[];
    for (final m in entries) {
      final text = (m['text'] ?? '').toLowerCase();
      final author = (m['author'] ?? '').toLowerCase();
      if (text.contains(search) || author.contains(search)) {
        results.add(_mapToQuote(m));
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  Iterable<Map<String, String>> allLocalEntries() => localQuotes;

  Iterable<Map<String, String>> _localEntriesFor(Category? category) {
    if (category == null) {
      return localQuotes;
    }
    final keys = category.keywords.map((e) => e.toLowerCase()).toList();
    final hits = localQuotes.where((m) {
      final text = (m['text'] ?? '').toLowerCase();
      return keys.any((k) => text.contains(k));
    }).toList();
    if (hits.isEmpty) {
      return localQuotes;
    }
    return hits;
  }

  Quote _mapToQuote(Map<String, String> m) {
    final text = (m['text'] ?? '').trim();
    final author = (m['author'] ?? '').trim();
    return Quote(text, author.isEmpty ? 'Unknown' : author, 'Local');
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
