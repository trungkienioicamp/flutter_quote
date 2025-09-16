import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'src/app_state.dart';
import 'src/categories.dart';
import 'src/quote_service.dart';
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
        final scheme = isDark ? const ColorScheme.dark() : const ColorScheme.light();
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      QuotePage(service: _svc, category: null, title: 'Random Quote'),
      CategoryTab(service: _svc),
      const FavoritesPage(),
      const SettingsPage(),
    ];

    return ThemedScaffold(
      // no title -> no AppBar
      title: null,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Category',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Favourite',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
      ),
    );
  }
}

/// Reusable quote viewer page with swipe gestures and navigation controls.
/// If [category] is null => Home (Random).
class QuotePage extends StatefulWidget {
  final QuoteService service;
  final Category? category;
  final String? title;

  const QuotePage({
    super.key,
    required this.service,
    required this.category,
    this.title,
  });

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> {
  final List<Quote> _history = [];
  int _cursor = -1; // index of current quote in history
  bool _loading = true;
  String? _hint;
  int _swipeDir = 1; // 1 = up/next, -1 = down/prev

  Quote? get _current =>
      (_cursor >= 0 && _cursor < _history.length) ? _history[_cursor] : null;

  @override
  void initState() {
    super.initState();
    // persist last used category (if any)
    if (widget.category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().setLastCategory(widget.category!.name);
      });
    }
    Future.microtask(() async {
      await widget.service.prefetch(widget.category, desired: 10);
      if (!mounted) return;
      _loadNext(initial: true);
    });
  }

  Future<void> _loadNext({bool initial = false}) async {
    setState(() {
      _loading = true;
      if (!initial) {
        _hint = null;
        _swipeDir = 1;
      }
    });

    try {
      // If user had gone back, allow forward navigation through history
      if (_cursor < _history.length - 1) {
        setState(() {
          _cursor++;
        });
      } else {
        final q = await widget.service.next(widget.category);
        setState(() {
          _history.add(q);
          _cursor = _history.length - 1;
        });
      }
    } on Cooldown catch (c) {
      setState(() => _hint = 'Easy 🙂 Try again in ~${c.remaining.inSeconds.clamp(1, 9)}s');
    } catch (_) {
      final q = widget.service.localQuote(widget.category);
      setState(() {
        _history.add(q);
        _cursor = _history.length - 1;
        _hint = 'Network issue — showing a local quote.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goPrev() {
    if (_cursor > 0) {
      setState(() {
        _swipeDir = -1;
        _cursor--;
      });
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('No previous quote')));
    }
  }

  void _onVerticalEnd(DragEndDetails d) {
    final vy = d.primaryVelocity ?? 0;
    if (vy < -200) {
      // swipe up -> next
      _loadNext();
    } else if (vy > 200) {
      // swipe down -> prev
      _goPrev();
    }
  }

  void _shareCurrent() async {
    final q = _current;
    if (q == null) return;
    final text = '“${q.content}” — ${q.author}';
    try {
      await Share.share(text, subject: 'Quote');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not supported on this platform/browser')),
      );
    }
  }

  void _toggleFavorite(AppState app) {
    final q = _current;
    if (q == null) return;
    app.toggleFavorite(q);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final textColor = app.foreground;
    final isFav = _current != null && app.isFavorite(_current!);

    final bodyChild = _loading
        ? const Center(child: CircularProgressIndicator())
        : _current == null
            ? _EmptyState(onRetry: _loadNext)
            : _QuoteView(
                key: ValueKey('q$_cursor'),
                quote: _current!,
                hint: _hint,
                textColor: textColor,
                onShare: _shareCurrent,
                isFavorite: isFav,
                onToggleFavorite: () => _toggleFavorite(app),
              );
    return ThemedScaffold(
      // no title -> no AppBar
      title: null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onVerticalDragEnd: _onVerticalEnd,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) {
                final beginOffset = Offset(0, _swipeDir == 1 ? 1 : -1);
                final tween = Tween<Offset>(begin: beginOffset, end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic))
                    .animate(anim);
                return SlideTransition(position: tween, child: child);
              },
              child: bodyChild,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonalIcon(
                    onPressed:
                        (!_loading && _cursor > 0) ? _goPrev : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Prev'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            _loadNext();
                          },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      // no title -> no AppBar
      title: null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (last != null) ...[
            InkWell(
              onTap: () {
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
                        'Last used: ${last.name}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor),
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
                      Text(c.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: textColor)),
                      const SizedBox(height: 4),
                      Text(c.subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: textColor.withOpacity(0.8))),
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

class _QuoteView extends StatelessWidget {
  final Quote quote;
  final String? hint;
  final Color textColor;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;

  const _QuoteView({
    super.key,
    required this.quote,
    this.hint,
    required this.textColor,
    required this.onShare,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          key: const ValueKey('quote'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hint != null) ...[
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.9),
                  )),
              const SizedBox(height: 8),
            ],
            Icon(Icons.format_quote, size: 48, color: textColor),
            const SizedBox(height: 12),
            Text(
              quote.content,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.4,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '— ${quote.author}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Share',
                  onPressed: onShare,
                  icon: Icon(Icons.share, color: textColor),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isFavorite ? 'Unstar' : 'Star',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : textColor,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textColor = context.select<AppState, Color>((s) => s.foreground);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48, color: textColor),
            const SizedBox(height: 12),
            Text('No quote yet',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: textColor)),
            const SizedBox(height: 8),
            Text(
              'Use the arrows below to browse quotes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// FAVOURITES PAGE
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.favorites;
    final textColor = app.foreground;

    return ThemedScaffold(
      // no title -> no AppBar
      title: null,
      body: items.isEmpty
          ? Center(
              child: Text(
                'No favourites yet.\nTap the star under a quote to save it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor),
              ),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— ${q.author}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor.withOpacity(0.9)),
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
                                  const SnackBar(content: Text('Sharing is not supported on this platform/browser')),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: app.foreground)),
          const SizedBox(height: 12),
          _ColorGrid(
            colors: kWarmColors,
            selected: app.color,
            onPick: (c) => context.read<AppState>().setColor(c),
          ),
          const SizedBox(height: 28),
          Text('Last used category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: app.foreground)),
          const SizedBox(height: 8),
          Text(
            app.lastCategoryName ?? 'None',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: app.foreground),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: app.foreground)),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: app.foreground),
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
                  color: selected.value == c.value ? Colors.white : Colors.black26,
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
