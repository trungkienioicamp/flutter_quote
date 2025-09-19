import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../categories.dart';
import '../quote_service.dart';
import '../pages/quote_page.dart';

class QuoteSearchDelegate extends SearchDelegate<Quote?> {
  final QuoteService service;
  final ValueChanged<Category>? onCategorySelected;

  QuoteSearchDelegate({
    required this.service,
    this.onCategorySelected,
  });

  Category? _activeCategory;

  @override
  String get searchFieldLabel => 'Search quotes or authors';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = service.searchLocalQuotes(
      query,
      category: _activeCategory,
      limit: 80,
    );
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No matches found. Try different keywords or pick a category.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return _QuoteResultList(quotes: results, service: service);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _CategorySuggestionList(
        onSelect: (category) {
          _activeCategory = category;
          close(context, null);
          onCategorySelected?.call(category);
        },
      );
    }
    return buildResults(context);
  }
}

class _CategorySuggestionList extends StatelessWidget {
  final ValueChanged<Category> onSelect;

  const _CategorySuggestionList({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: kCategories.length,
      itemBuilder: (context, index) {
        final category = kCategories[index];
        return ListTile(
          leading: Icon(category.icon),
          title: Text(category.name),
          subtitle: Text('Browse curated ${category.subtitle} quotes'),
          onTap: () => onSelect(category),
        );
      },
    );
  }
}

class _QuoteResultList extends StatelessWidget {
  final List<Quote> quotes;
  final QuoteService service;

  const _QuoteResultList({required this.quotes, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: quotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return _ResultTile(quote: quote, service: service);
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Quote quote;
  final QuoteService service;

  const _ResultTile({required this.quote, required this.service});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isFav = app.isFavorite(quote);
    final textColor = app.surfaceForeground;
    final cardColor = app.surfaceColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“${quote.content}”',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: textColor, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              '— ${quote.author}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: textColor.withOpacity(0.85)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Read more like this',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuotePage(
                          service: service,
                          category: null,
                          title: 'Quote',
                          initialQuote: quote,
                        ),
                      ),
                    );
                  },
                  icon:
                      Icon(Icons.chrome_reader_mode_outlined, color: textColor),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () async {
                    try {
                      await Share.share('“${quote.content}” — ${quote.author}');
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Sharing unavailable on this device.')),
                      );
                    }
                  },
                  icon: Icon(Icons.share_outlined, color: textColor),
                ),
                IconButton(
                  tooltip:
                      isFav ? 'Remove from favourites' : 'Save to favourites',
                  onPressed: () => app.toggleFavorite(quote),
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
