// Run with: dart run tool/make_quotes.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const rawUrl =
    'https://raw.githubusercontent.com/JamesFT/Database-Quotes-JSON/master/quotes.json';
const apiUrl =
    'https://api.github.com/repos/JamesFT/Database-Quotes-JSON/contents/quotes.json?ref=master';

Future<void> main() async {
  String jsonText;

  // --- Try RAW GitHub first (plain JSON) ---
  try {
    final r = await http.get(
      Uri.parse(rawUrl),
      headers: {
        'User-Agent': 'dart/quotes-generator',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip', // avoid brotli surprises
      },
    );
    if (r.statusCode != 200) {
      throw Exception('raw ${r.statusCode}');
    }
    jsonText = r.body; // http decompresses gzip for us
  } catch (e) {
    stdout.writeln('Raw download failed ($e). Trying GitHub API …');

    // --- Fallback: GitHub API returns base64 content ---
    final r = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'User-Agent': 'dart/quotes-generator',
        'Accept': 'application/vnd.github.v3+json',
      },
    );
    if (r.statusCode != 200) {
      throw Exception('GitHub API error: HTTP ${r.statusCode}');
    }
    final obj = jsonDecode(r.body) as Map<String, dynamic>;
    final contentB64 = (obj['content'] as String?)?.replaceAll('\n', '');
    if (contentB64 == null || contentB64.isEmpty) {
      throw Exception('No content in API response');
    }
    final decoded = base64.decode(contentB64);
    jsonText = utf8.decode(decoded, allowMalformed: true);
  }

  // Parse either dataset shape: {quoteText, quoteAuthor} or {text, author}
  final data = jsonDecode(jsonText) as List<dynamic>;
  final items = <Map<String, String>>[];
  for (final e in data) {
    final m = e as Map<String, dynamic>;
    final text = (m['quoteText'] ?? m['text'] ?? '').toString().trim();
    if (text.isEmpty) continue;
    final author = (m['quoteAuthor'] ?? m['author'] ?? 'Unknown')
        .toString()
        .trim();
    items.add({
      'text': text,
      'author': author.isEmpty ? 'Unknown' : author,
    });
  }

  // Shuffle and keep a healthy amount (adjust as you like)
  items.shuffle();
  final keep = items.take(1500).toList(); // >= 500 as requested

  // Escape for Dart string literals
  String esc(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('\r', '')
      .replaceAll('\n', r'\n')
      .replaceAll('"', r'\"')
      .replaceAll('\$', r'\$');

  final buf = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('// Source: $rawUrl')
    ..writeln('/// Minimal map shape to avoid importing main.dart')
    ..writeln('const List<Map<String, String>> localQuotes = [');

  for (final q in keep) {
    buf.writeln(
        '  {"text":"${esc(q['text']!)}","author":"${esc(q['author']!)}"},');
  }
  buf.writeln('];');

  await Directory('lib').create(recursive: true);
  final out = File('lib/quotes.dart');
  await out.writeAsString(buf.toString());
  stdout.writeln('Wrote ${keep.length} quotes to ${out.path}');
}
