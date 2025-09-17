import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// A scaffold that paints the chosen background COLOR
/// and adapts foreground colors automatically.
class ThemedScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? appBarBottom;
  final bool? centerTitle;

  const ThemedScaffold({
    super.key,
    this.title,
    this.titleWidget,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.actions,
    this.leading,
    this.appBarBottom,
    this.centerTitle,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bgColor = app.color;
    final isDark = app.isDark;
    final fg = app.foreground;

    final appBarColor =
        isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.35);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background color
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: bgColor),
          ),
        ),
        // Foreground scaffold
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: title == null && titleWidget == null && actions == null && leading == null && appBarBottom == null
              ? null
              : AppBar(
                  backgroundColor: appBarColor,
                  elevation: 0,
                  centerTitle: centerTitle ?? true,
                  title: titleWidget ??
                      (title != null
                          ? Text(title!, style: TextStyle(color: fg))
                          : null),
                  titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg),
                  toolbarTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
                  actions: actions,
                  leading: leading,
                  bottom: appBarBottom,
                  iconTheme: IconThemeData(color: fg),
                  actionsIconTheme: IconThemeData(color: fg),
                ),
          body: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: body,
          ),
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
        ),
      ],
    );
  }
}
