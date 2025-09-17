import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:showcaseview/showcaseview.dart';

import 'src/app_state.dart';
import 'src/categories.dart';
import 'src/quote_service.dart';
import 'src/discover_page.dart';
import 'src/pages/quote_page.dart';
import 'src/widgets/themed_scaffold.dart';
import 'src/backgrounds.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState.init(),
      child: const QuoteApp(),
    ),
  );
}

class QuoteApp extends StatelessWidget {
  const QuoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final isDark = app.isDark;
        final scheme =
            isDark ? const ColorScheme.dark() : const ColorScheme.light();
        return MaterialApp(
          title: 'Quotes',
          theme: ThemeData(
            colorScheme: scheme,
            useMaterial3: true,
          ),
          home: const RootScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  final _svc = QuoteService();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _favoritesKey = GlobalKey();
  bool _showcaseScheduled = false;

  void _setIndex(int value) {
    if (_index == value) return;
    setState(() => _index = value);
  }

  void _maybeStartShowcase(BuildContext showCaseContext) {
    if (_showcaseScheduled) return;
    final app = context.read<AppState>();
    if (!app.needsOnboarding) return;
    _showcaseScheduled = true;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ShowCaseWidget.of(showCaseContext).startShowCase([
        _searchKey,
        _categoryKey,
        _favoritesKey,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DiscoverPage(
        service: _svc,
        searchShowcaseKey: _searchKey,
        firstCategoryShowcaseKey: _categoryKey,
        onOpenFavorites: () => _setIndex(2),
        onOpenCategories: () => _setIndex(1),
        onCategoryDeepDive: (_) => _setIndex(1),
      ),
      CategoryTab(service: _svc),
      FavoritesPage(service: _svc, onOpenDiscover: () => _setIndex(0)),
      const SettingsPage(),
    ];

    return ShowCaseWidget(
      onFinish: () => context.read<AppState>().markOnboardingSeen(),
      builder: Builder(
        builder: (showcaseContext) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeStartShowcase(showcaseContext);
          });
          return ThemedScaffold(
            title: null,
            body: IndexedStack(index: _index, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Discover',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: 'Categories',
                ),
                NavigationDestination(
                  icon: Showcase(
                    key: _favoritesKey,
                    description: 'View every quote you have saved for later.',
                    child: const Icon(Icons.star_border),
                  ),
                  selectedIcon: const Icon(Icons.star),
                  label: 'Favourites',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CategoryTab extends StatelessWidget {
  final QuoteService service;
  const CategoryTab({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final textColor = app.foreground;

    final last = app.lastCategoryName != null
        ? findCategoryByName(app.lastCategoryName!)
        : null;

    return ThemedScaffold(
      title: null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (last != null) ...[
            InkWell(
              onTap: () {
                context.read<AppState>().setLastCategory(last.name);
                unawaited(service.prefetch(last, desired: 10));
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuotePage(
                      service: service,
                      category: last,
                      title: last.name,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: textColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Last opened: ${last.name}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: textColor),
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: textColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: kCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 4 / 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final c = kCategories[i];
              return InkWell(
                onTap: () {
                  context.read<AppState>().setLastCategory(c.name);
                  unawaited(service.prefetch(c, desired: 10));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuotePage(
                        service: service,
                        category: c,
                        title: c.name,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: kElevationToShadow[1],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(c.icon, size: 40, color: textColor),
                      const SizedBox(height: 8),
                      Text(
                        c.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: textColor.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// FAVOURITES PAGE
class FavoritesPage extends StatelessWidget {
  final QuoteService service;
  final VoidCallback onOpenDiscover;
  const FavoritesPage({
    super.key,
    required this.service,
    required this.onOpenDiscover,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.favorites;
    final textColor = app.foreground;
    final suggestions = service.localQuotesForCategory(null, limit: 3);

    return ThemedScaffold(
      // no title -> no AppBar
      title: null,
      body: items.isEmpty
          ? _FavoritesEmptyState(
              textColor: textColor,
              suggestions: suggestions,
              onOpenDiscover: onOpenDiscover,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final q = items[i];
                final isFav = app.isFavorite(q);
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '“${q.content}”',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: textColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— ${q.author}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: textColor.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Share',
                            onPressed: () async {
                              final text = '“${q.content}” — ${q.author}';
                              try {
                                await Share.share(text, subject: 'Quote');
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Sharing is not supported on this platform/browser')),
                                );
                              }
                            },
                            icon: Icon(Icons.share, color: textColor),
                          ),
                          IconButton(
                            tooltip: isFav ? 'Unstar' : 'Star',
                            onPressed: () => app.toggleFavorite(q),
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: isFav ? Colors.amber : textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  final Color textColor;
  final List<Quote> suggestions;
  final VoidCallback onOpenDiscover;

  const _FavoritesEmptyState({
    required this.textColor,
    required this.suggestions,
    required this.onOpenDiscover,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Save quotes you love',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the star icon on any quote to store it here. Here are a few to get you started:',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor.withOpacity(0.9)),
            ),
            const SizedBox(height: 16),
            if (suggestions.isEmpty)
              Text(
                'Offline samples unavailable — browse Discover to load fresh quotes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withOpacity(0.9)),
              )
            else
              for (final quote in suggestions)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '“${quote.content}”',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: textColor, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— ${quote.author}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: textColor.withOpacity(0.85)),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenDiscover,
              icon: const Icon(Icons.explore),
              label: const Text('Discover quotes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// SETTINGS (Color-only)
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ThemedScaffold(
      // no title -> no AppBar
      title: null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Background Color',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: app.foreground)),
          const SizedBox(height: 12),
          _ColorGrid(
            colors: kWarmColors,
            selected: app.color,
            onPick: (c) => context.read<AppState>().setColor(c),
          ),
          const SizedBox(height: 28),
          Text('Last used category',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: app.foreground)),
          const SizedBox(height: 8),
          Text(
            app.lastCategoryName ?? 'None',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: app.foreground),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: app.lastCategoryName == null
                    ? null
                    : () => context.read<AppState>().clearLastCategory(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Preview',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: app.foreground)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ThemedScaffold(
              // no title in preview either
              title: null,
              body: Center(
                child: Text(
                  '“The only way out is through.”\n— Robert Frost',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: app.foreground),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;

  const _ColorGrid({
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      selected.value == c.value ? Colors.white : Colors.black26,
                  width: selected.value == c.value ? 3 : 1,
                ),
                boxShadow: kElevationToShadow[1],
              ),
            ),
          ),
      ],
    );
  }
}
