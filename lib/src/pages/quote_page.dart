import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../categories.dart';
import '../quote_service.dart';
import '../widgets/themed_scaffold.dart';

class QuotePage extends StatefulWidget {
  final QuoteService service;
  final Category? category;
  final String? title;
  final Quote? initialQuote;

  const QuotePage({
    super.key,
    required this.service,
    required this.category,
    this.title,
    this.initialQuote,
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
    if (widget.initialQuote != null) {
      _history.add(widget.initialQuote!);
      _cursor = 0;
      _loading = false;
    }
    // persist last used category (if any)
    if (widget.category != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().setLastCategory(widget.category!.name);
      });
    }
    Future.microtask(() async {
      await widget.service.prefetch(widget.category, desired: 10);
      if (!mounted) return;
      if (_history.isEmpty) {
        _loadNext(initial: true);
      }
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
      setState(() => _hint =
          'Easy 🙂 Try again in ~${c.remaining.inSeconds.clamp(1, 9)}s');
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
        const SnackBar(
            content: Text('Sharing is not supported on this platform/browser')),
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
            ? _EmptyState(
                onRetry: _loadNext,
                samples: widget.service
                    .localQuotesForCategory(widget.category, limit: 3),
              )
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
      title: widget.title,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onVerticalDragEnd: _onVerticalEnd,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) {
                final beginOffset = Offset(0, _swipeDir == 1 ? 1 : -1);
                final tween =
                    Tween<Offset>(begin: beginOffset, end: Offset.zero)
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
                    onPressed: (!_loading && _cursor > 0) ? _goPrev : null,
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
            Text(
              '“${quote.content}”',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: textColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '— ${quote.author}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: textColor.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: isFavorite ? 'Unsave' : 'Save to favourites',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : textColor,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Share this quote',
                  onPressed: onShare,
                  icon: Icon(Icons.share, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Swipe up for the next quote or down to revisit previous ones.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  final List<Quote> samples;

  const _EmptyState({required this.onRetry, required this.samples});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final textColor = app.foreground;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(
              'No quotes yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the arrows below to browse quotes. Meanwhile, here are a few favourites:',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor.withOpacity(0.9)),
            ),
            const SizedBox(height: 16),
            for (final quote in samples)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SampleQuoteCard(quote: quote, textColor: textColor),
              ),
            const SizedBox(height: 12),
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

class _SampleQuoteCard extends StatelessWidget {
  final Quote quote;
  final Color textColor;

  const _SampleQuoteCard({required this.quote, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
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
                ?.copyWith(color: textColor.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}
