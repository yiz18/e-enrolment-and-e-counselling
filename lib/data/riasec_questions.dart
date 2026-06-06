import 'package:flutter/material.dart';

// =============================================================================
// RiasecSection — data descriptor for one Holland dimension
// =============================================================================

class RiasecSection {
  final String code;
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;

  /// Exactly 8 question stems. Index 0 → item key "<code>1", index 7 → "<code>8".
  final List<String> questions;

  const RiasecSection({
    required this.code,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.questions,
  });

  /// Returns the API-compatible field name for question at [index] (0-based).
  /// e.g. RiasecSection(code:'R').fieldName(0) == 'R1'
  String fieldName(int index) => '$code${index + 1}';
}

// =============================================================================
// The 6 sections — colors and icons match interest_profile_screen.dart
// =============================================================================

const List<RiasecSection> kRiasecSections = [
  // ── R — Realistic ──────────────────────────────────────────────────────────
  RiasecSection(
    code: 'R',
    name: 'Realistic',
    tagline: 'Hands-on work with tools, machines & nature',
    icon: Icons.build_outlined,
    color: Color(0xFF546E7A),
    questions: [
      'Build or repair things using hand or power tools',
      'Operate machinery or specialised equipment',
      'Work outdoors or in a natural environment',
      'Troubleshoot and fix mechanical or electrical problems',
      'Assemble, install, or maintain physical systems',
      'Do physical, athletic, or manual labour activities',
      'Work with plants, animals, or natural materials',
      'Follow technical drawings, blueprints, or schematics',
    ],
  ),

  // ── I — Investigative ──────────────────────────────────────────────────────
  RiasecSection(
    code: 'I',
    name: 'Investigative',
    tagline: 'Explore ideas, research, and solve complex problems',
    icon: Icons.science_outlined,
    color: Color(0xFF3949AB),
    questions: [
      'Conduct scientific experiments or research studies',
      'Analyse data or statistics to uncover patterns',
      'Solve complex mathematical or logical problems',
      'Read academic journals, research papers, or technical books',
      'Investigate how things work at a deep level',
      'Develop new theories, models, or explanations',
      'Work in a laboratory or research environment',
      'Think critically and question assumptions',
    ],
  ),

  // ── A — Artistic ───────────────────────────────────────────────────────────
  RiasecSection(
    code: 'A',
    name: 'Artistic',
    tagline: 'Create and express through arts, design & writing',
    icon: Icons.palette_outlined,
    color: Color(0xFF8E24AA),
    questions: [
      'Create original artwork, illustrations, or sculptures',
      'Write stories, poetry, scripts, or creative content',
      'Perform in music, dance, theatre, or film',
      'Design graphics, user interfaces, or visual layouts',
      'Brainstorm and develop imaginative, unconventional ideas',
      'Express yourself freely through creative outlets',
      'Attend or participate in art, music, or cultural events',
      'Work in a flexible, unstructured environment',
    ],
  ),

  // ── S — Social ─────────────────────────────────────────────────────────────
  RiasecSection(
    code: 'S',
    name: 'Social',
    tagline: 'Help, teach, and connect with people',
    icon: Icons.people_outline,
    color: Color(0xFF388E3C),
    questions: [
      'Help people navigate personal or emotional challenges',
      'Teach, train, or tutor others to develop new skills',
      'Collaborate closely with a team toward a shared goal',
      'Provide care or support to people in need',
      'Listen attentively and offer thoughtful advice',
      'Organise community events or group activities',
      'Work in healthcare, education, or social services',
      'Build lasting, meaningful relationships with others',
    ],
  ),

  // ── E — Enterprising ───────────────────────────────────────────────────────
  RiasecSection(
    code: 'E',
    name: 'Enterprising',
    tagline: 'Lead, persuade, and drive results',
    icon: Icons.trending_up,
    color: Color(0xFFEF6C00),
    questions: [
      'Lead or manage a team to achieve a common goal',
      'Start, grow, or run a business or entrepreneurial venture',
      'Persuade or influence others to accept your viewpoint',
      'Take charge in high-pressure or uncertain situations',
      'Sell products, services, or ideas to clients or customers',
      'Negotiate agreements or close deals',
      'Set ambitious goals and motivate others to reach them',
      'Compete to advance your career or achieve recognition',
    ],
  ),

  // ── C — Conventional ───────────────────────────────────────────────────────
  RiasecSection(
    code: 'C',
    name: 'Conventional',
    tagline: 'Organise, plan, and work with data and systems',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF00796B),
    questions: [
      'Keep detailed records, files, or databases well organised',
      'Follow established rules, standards, or procedures precisely',
      'Work with numbers, spreadsheets, or large datasets',
      'Prepare written reports, forms, or documentation',
      'Enter, verify, and process data with high accuracy',
      'Work in a structured, predictable, and orderly environment',
      'Handle financial, accounting, or administrative tasks',
      'Use software tools to organise and manage information',
    ],
  ),
];

// =============================================================================
// Likert scale labels — 1 to 5 (matches training data range)
// =============================================================================

const List<String> kLikertLabels = [
  'Dislike',
  'Slightly\nDislike',
  'Neutral',
  'Slightly\nLike',
  'Like',
];
