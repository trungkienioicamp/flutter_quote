import 'package:flutter/material.dart';

class Category {
  final String name;
  final String subtitle;
  final IconData icon;

  /// Tags used for Quotable (OR-ed with "|")
  final List<String> tags;

  /// Simple keyword filters for local fallback
  final List<String> keywords;

  const Category({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.tags,
    required this.keywords,
  });
}

const kCategories = <Category>[
  Category(
    name: 'Life',
    subtitle: 'living well',
    icon: Icons.self_improvement,
    tags: ['life', 'philosophy', 'inspirational'],
    keywords: ['life', 'living', 'purpose', 'journey', 'existence', 'meaning', 'grow', 'learn'],
  ),
  Category(
    name: 'Love',
    subtitle: 'heart & kindness',
    icon: Icons.favorite,
    tags: ['love', 'romance', 'kindness'],
    keywords: ['love', 'loving', 'heart', 'affection', 'kindness', 'compassion'],
  ),
  Category(
    name: 'Study',
    subtitle: 'learn & improve',
    icon: Icons.menu_book,
    tags: ['education', 'learning', 'study'],
    keywords: ['study', 'learn', 'education', 'teacher', 'student', 'knowledge'],
  ),
  Category(
    name: 'Motivation',
    subtitle: 'get moving',
    icon: Icons.flash_on,
    tags: ['motivational', 'inspirational', 'success'],
    keywords: ['motivation', 'inspire', 'drive', 'ambition', 'goal', 'dream', 'action', 'start', 'habit'],
  ),
  Category(
    name: 'Friendship',
    subtitle: 'friends & support',
    icon: Icons.group,
    tags: ['friendship'],
    keywords: ['friend', 'friendship', 'companionship', 'company', 'together'],
  ),
  Category(
    name: 'Family',
    subtitle: 'home & roots',
    icon: Icons.home,
    tags: ['family', 'parenting'],
    keywords: ['family', 'mother', 'father', 'parent', 'child', 'home'],
  ),
  Category(
    name: 'Happiness',
    subtitle: 'joy & peace',
    icon: Icons.emoji_emotions,
    tags: ['happiness', 'positive'],
    keywords: ['happy', 'happiness', 'joy', 'smile', 'delight', 'cheer', 'content'],
  ),
  Category(
    name: 'Wisdom',
    subtitle: 'think deeply',
    icon: Icons.psychology,
    tags: ['wisdom', 'philosophy'],
    keywords: ['wisdom', 'wise', 'truth', 'insight', 'understand', 'knowledge'],
  ),
  Category(
    name: 'Courage',
    subtitle: 'brave & bold',
    icon: Icons.shield,
    tags: ['courage', 'fear'],
    keywords: ['courage', 'brave', 'fear', 'bold', 'risk', 'dare'],
  ),
  Category(
    name: 'Leadership',
    subtitle: 'guide & grow',
    icon: Icons.workspace_premium,
    tags: ['leadership', 'business'],
    keywords: ['lead', 'leader', 'leadership', 'team', 'vision', 'influence'],
  ),
  Category(
    name: 'Mindfulness',
    subtitle: 'present moment',
    icon: Icons.spa,
    tags: ['mindfulness', 'peace'],
    keywords: ['mindful', 'mindfulness', 'present', 'breathe', 'peace', 'calm', 'meditation'],
  ),
  Category(
    name: 'Gratitude',
    subtitle: 'thankfulness',
    icon: Icons.favorite_border,
    tags: ['gratitude'],
    keywords: ['gratitude', 'grateful', 'thankful', 'appreciate', 'bless'],
  ),
  Category(
    name: 'Perseverance',
    subtitle: 'keep going',
    icon: Icons.trending_up,
    tags: ['perseverance', 'determination'],
    keywords: ['persevere', 'perseverance', 'determination', 'grit', 'persist', 'endure'],
  ),
];
