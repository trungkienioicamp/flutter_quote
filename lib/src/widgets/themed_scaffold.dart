import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

/// A scaffold that paints the chosen background COLOR
/// and adapts foreground colors automatically.
class ThemedScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const ThemedScaffold({
    super.key,
    this.title,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
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
          appBar: title == null
              ? null
              : AppBar(
                  backgroundColor: appBarColor,
                  elevation: 0,
                  centerTitle: true,
                  title: Text(title!, style: TextStyle(color: fg)),
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
