import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:showcaseview/showcaseview.dart';

import 'app_state.dart';
import 'categories.dart';
import 'quote_service.dart';
import 'widgets/quote_search_delegate.dart';
import 'widgets/themed_scaffold.dart';
import 'pages/quote_page.dart';

class DiscoverPage extends StatefulWidget {
  final QuoteService service;
  final GlobalKey? searchShowcaseKey;
  final GlobalKey? firstCategoryShowcaseKey;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenCategories;
  final ValueChanged<Category>? onCategoryDeepDive;

  const DiscoverPage({
    super.key,
    required this.service,
    this.searchShowcaseKey,
    this.firstCategoryShowcaseKey,
    required this.onOpenFavorites,
    required this.onOpenCategories,
    this.onCategoryDeepDive,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late Quote _quoteOfTheDay;
  late List<Quote> _editorsPicks;
  late Map<Category, List<Quote>> _categoryDecks;
  late List<_AuthorSpotlight> _authorSpotlights;
  bool _ready = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _buildLocalCollections();
  }

  void _buildLocalCollections() {
    final todaysIndex = DateTime.now().difference(DateTime(2020, 1, 1)).inDays;
    final allPool = widget.service.localQuotesForCategory(null, limit: 400);
    if (allPool.isEmpty) {
      if (mounted) {
        setState(() => _ready = true);
      }
      return;
    }
    _quoteOfTheDay = allPool[todaysIndex % allPool.length];

    final featured = List<Quote>.from(allPool);
    featured.shuffle(_rng);
    _editorsPicks = featured.take(15).toList();

    final shuffledCategories = List<Category>.from(kCategories);
    shuffledCategories.shuffle(_rng);
    final decks = <Category, List<Quote>>{};
    for (final c in shuffledCategories.take(6)) {
      decks[c] = widget.service.localQuotesForCategory(c, limit: 12);
    }
    _categoryDecks = decks;

    final authorBuckets = <String, List<Quote>>{};
    for (final quote in allPool) {
      authorBuckets.putIfAbsent(quote.author, () => []).add(quote);
    }
    final spotlights = authorBuckets.entries
        .where((entry) => entry.key.isNotEmpty)
        .map((entry) {
      final samples = List<Quote>.from(entry.value)..shuffle(_rng);
      return _AuthorSpotlight(
        author: entry.key,
        samples: samples.take(3).toList(),
        total: entry.value.length,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    _authorSpotlights = spotlights.take(6).toList();

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  void _openSearch() {
    final nav = Navigator.of(context);
    showSearch<Quote?>(
      context: context,
      delegate: QuoteSearchDelegate(
        service: widget.service,
        onCategorySelected: (category) {
          widget.onCategoryDeepDive?.call(category);
          nav.push(
            MaterialPageRoute(
              builder: (_) => QuotePage(
                service: widget.service,
                category: category,
                title: category.name,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openQuoteReader([Quote? seed]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotePage(
          service: widget.service,
          category: null,
          title: seed == null ? 'Random Quote' : 'Daily Pick',
          initialQuote: seed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ThemedScaffold(
        title: 'Discover',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final searchButton = IconButton(
      icon: const Icon(Icons.search),
      onPressed: _openSearch,
      tooltip: 'Search quotes',
    );

    return ThemedScaffold(
      title: 'Discover',
      actions: [
        if (widget.searchShowcaseKey != null)
          Showcase(
            key: widget.searchShowcaseKey!,
            description: 'Search across hundreds of curated quotes and authors',
            child: searchButton,
          )
        else
          searchButton,
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _ready = false);
          await Future<void>.delayed(const Duration(milliseconds: 250));
          _buildLocalCollections();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            _DailyQuoteCard(
              quote: _quoteOfTheDay,
              onReadMore: _openQuoteReader,
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Editor picks',
              onViewAll: () => _openQuoteReader(),
            ),
            const SizedBox(height: 12),
            _QuoteCarousel(quotes: _editorsPicks, service: widget.service),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Browse categories',
              onViewAll: widget.onOpenCategories,
            ),
            const SizedBox(height: 12),
            _CategoryStrip(
              decks: _categoryDecks,
              service: widget.service,
              showcaseKey: widget.firstCategoryShowcaseKey,
              onCategoryDeepDive: widget.onCategoryDeepDive,
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Author spotlights',
              onViewAll: () =>
                  widget.onCategoryDeepDive?.call(kCategories.first),
            ),
            const SizedBox(height: 12),
            _AuthorSpotlightList(
                spotlights: _authorSpotlights, service: widget.service),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: widget.onOpenFavorites,
              icon: const Icon(Icons.star),
              label: const Text('Jump to favourites'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyQuoteCard extends StatelessWidget {
  final Quote quote;
  final ValueChanged<Quote?> onReadMore;

  const _DailyQuoteCard({
    required this.quote,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final textColor = app.surfaceForeground;
    final cardColor = app.surfaceColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quote of the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textColor.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '“${quote.content}”',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '— ${quote.author}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: textColor.withOpacity(0.85),
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: () => onReadMore(quote),
                  child: const Text('Keep reading'),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCarousel extends StatelessWidget {
  final List<Quote> quotes;
  final QuoteService service;

  const _QuoteCarousel({required this.quotes, required this.service});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: quotes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final quote = quotes[index];
          return SizedBox(
            width: 260,
            child: _QuoteCard(quote: quote, service: service),
          );
        },
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final Quote quote;
  final QuoteService service;

  const _QuoteCard({
    required this.quote,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isFav = app.isFavorite(quote);
    final textColor = app.surfaceForeground;
    final cardColor = app.surfaceColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '“${quote.content}”',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: textColor, height: 1.3),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              quote.author,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: textColor.withOpacity(0.8)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Share',
                  icon: Icon(Icons.share_outlined, color: textColor),
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
                ),
                IconButton(
                  tooltip: isFav ? 'Unsave' : 'Save',
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : textColor,
                  ),
                  onPressed: () =>
                      context.read<AppState>().toggleFavorite(quote),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  final Map<Category, List<Quote>> decks;
  final QuoteService service;
  final GlobalKey? showcaseKey;
  final ValueChanged<Category>? onCategoryDeepDive;

  const _CategoryStrip({
    required this.decks,
    required this.service,
    this.showcaseKey,
    this.onCategoryDeepDive,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tileColor = app.surfaceColor.withOpacity(app.isDark ? 0.6 : 0.9);
    final textColor = app.surfaceForeground;
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: decks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = decks.keys.elementAt(index);
          final summary = decks[category] ?? const [];
          final tile = GestureDetector(
            onTap: () => _openCategory(context, category),
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(category.icon, color: textColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    summary.isEmpty
                        ? 'Add quotes you love'
                        : 'Includes ${summary.length} curated quotes',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          );
          if (index == 0 && showcaseKey != null) {
            return Showcase(
              key: showcaseKey!,
              description: 'Tap any category to explore full collections.',
              child: tile,
            );
          }
          return tile;
        },
      ),
    );
  }

  void _openCategory(BuildContext context, Category category) {
    onCategoryDeepDive?.call(category);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotePage(
          service: service,
          category: category,
          title: category.name,
        ),
      ),
    );
  }
}

class _AuthorSpotlightList extends StatelessWidget {
  final List<_AuthorSpotlight> spotlights;
  final QuoteService service;

  const _AuthorSpotlightList({required this.spotlights, required this.service});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final app = context.watch<AppState>();
    final textColor = app.surfaceForeground;
    final cardColor = app.surfaceColor;
    return Column(
      children: [
        for (final spotlight in spotlights)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: cardColor,
            child: ListTile(
              title: Text(spotlight.author,
                  style: textTheme.titleMedium?.copyWith(color: textColor)),
              subtitle: Text(
                '${spotlight.total} quotes in library',
                style: textTheme.bodySmall?.copyWith(
                  color: textColor.withOpacity(0.8),
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: textColor),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AuthorQuotesPage(
                      author: spotlight.author,
                      quotes: spotlight.samples,
                      service: service,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AuthorQuotesPage extends StatelessWidget {
  final String author;
  final List<Quote> quotes;
  final QuoteService service;

  const _AuthorQuotesPage({
    required this.author,
    required this.quotes,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final allQuotes = List<Quote>.from(quotes)
      ..addAll(service.searchLocalQuotes(author, limit: 40));
    final deduped = <String, Quote>{};
    for (final quote in allQuotes) {
      deduped.putIfAbsent('${quote.content}|${quote.author}', () => quote);
    }
    final list = deduped.values.toList();
    return ThemedScaffold(
      title: author,
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _QuoteCard(
          quote: list[index],
          service: service,
        ),
      ),
    );
  }
}

class _AuthorSpotlight {
  final String author;
  final List<Quote> samples;
  final int total;

  _AuthorSpotlight({
    required this.author,
    required this.samples,
    required this.total,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View all'),
          ),
      ],
    );
  }
}
