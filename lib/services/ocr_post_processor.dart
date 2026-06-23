import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A single text fragment extracted from one [TextLine], with its spatial
/// position from the bounding box.
class OcrFragment {
  final String text;
  final double top;
  final double bottom;
  final double left;
  final double right;

  const OcrFragment({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  /// Vertical midpoint of this fragment's bounding box.
  /// Used as the representative Y-position for row-grouping.
  double get centerY => (top + bottom) / 2.0;

  /// Pixel height of this fragment's bounding box.
  double get height => bottom - top;
}

/// One reconstructed row — a group of [OcrFragment]s that share the same
/// vertical position, already sorted left-to-right.
class OcrRow {
  final List<OcrFragment> fragments;

  const OcrRow(this.fragments);

  /// Fragments joined with two spaces, preserving column order.
  String get text => fragments.map((f) => f.text).join('  ');
}

/// The complete post-processed result: a list of [OcrRow]s sorted
/// top-to-bottom, each row's fragments sorted left-to-right.
class OcrStructuredResult {
  final List<OcrRow> rows;

  const OcrStructuredResult(this.rows);

  /// Plain text reconstruction suitable for display or clipboard.
  String get plainText => rows.map((r) => r.text).join('\n');
}

/// Stateless post-processor that reconstructs reading order from raw ML Kit
/// [RecognizedText].
///
/// ML Kit groups characters into [TextBlock]s based on visual proximity, not
/// reading order. On documents with columns (e.g. subject names on the left,
/// grades on the right) each column may arrive as a separate block, breaking
/// the row association. This processor:
///
///   1. Flattens all [TextLine]s from every [TextBlock] into one list.
///   2. Sorts them by their bounding-box centerY coordinate (top → bottom).
///   3. Groups lines whose centerY values are within an adaptive threshold
///      into a single [OcrRow]. This is tolerant of slight photo tilt because
///      it measures the distance between midpoints rather than requiring a
///      pixel-level bounding-box overlap.
///   4. Sorts each row's fragments by their left coordinate (left → right).
///
/// No subject-grade parsing or domain logic is included here.
class OcrPostProcessor {
  const OcrPostProcessor._();

  /// Fraction of the average fragment height used as the row-grouping
  /// threshold.
  ///
  /// Two fragments are placed in the same row when the distance between their
  /// centerY values is ≤ (avgFragmentHeight × [_thresholdFactor]).
  ///
  /// Tuning guide:
  ///   0.40 – flat scanner output, very tight row spacing
  ///   0.60 – default; handles moderate phone-camera tilt (≈ 3°)
  ///   0.75 – recommended for noticeably tilted photos (≈ 5–8°)
  ///   1.00 – maximum; do not exceed or adjacent rows may merge
  static const double _thresholdFactor = 0.6;

  /// Processes [recognizedText] and returns a fully sorted [OcrStructuredResult].
  static OcrStructuredResult process(RecognizedText recognizedText) {
    final List<OcrFragment> fragments = _flatten(recognizedText);

    // Sort by centerY so the grouping algorithm sees fragments in approximate
    // top-to-bottom order regardless of which TextBlock they came from.
    fragments.sort((a, b) => a.centerY.compareTo(b.centerY));

    final List<List<OcrFragment>> rowGroups = _groupIntoRows(fragments);

    final List<OcrRow> rows = rowGroups.map((group) {
      group.sort((a, b) => a.left.compareTo(b.left));
      return OcrRow(List.unmodifiable(group));
    }).toList(growable: false);

    return refineRows(OcrStructuredResult(rows));
  }

  /// Builds an [OcrStructuredResult] from pre-extracted [fragments] using the
  /// same row grouping and orphan-merge pipeline as [process].
  static OcrStructuredResult processFragments(List<OcrFragment> fragments) {
    final sorted = List<OcrFragment>.from(fragments)
      ..sort((a, b) => a.centerY.compareTo(b.centerY));

    final rowGroups = _groupIntoRows(sorted);
    final rows = rowGroups.map((group) {
      group.sort((a, b) => a.left.compareTo(b.left));
      return OcrRow(List.unmodifiable(group));
    }).toList(growable: false);

    return refineRows(OcrStructuredResult(rows));
  }

  /// Re-applies orphan grade/subject row merging to an existing result.
  static OcrStructuredResult refineRows(OcrStructuredResult input) {
    final merged = _mergeOrphanGradeRows(input.rows);
    final consolidated =
        merged.map(_consolidateRowSubjects).toList(growable: false);
    return OcrStructuredResult(List.unmodifiable(consolidated));
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static final RegExp _gradePattern = RegExp(
    r'^([A-E])\s*([+\-]?)\s*(?:\([^)]*\))?$',
    caseSensitive: false,
  );

  static final RegExp _descriptionPattern = RegExp(r'^\(.*\)$');

  static bool _isGradeFragment(String text) =>
      _gradePattern.hasMatch(text.trim());

  static bool _isDescriptionFragment(String text) =>
      _descriptionPattern.hasMatch(text.trim());

  static bool _isPartialDescriptionFragment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('(') && !trimmed.endsWith(')')) return true;
    if (trimmed.endsWith(')') && !trimmed.startsWith('(')) return true;
    return false;
  }

  static bool _isNoiseFragment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.length == 1 && !_isGradeFragment(trimmed)) return true;
    return false;
  }

  static bool _isSubjectFragment(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 3) return false;
    if (_isGradeFragment(trimmed)) return false;
    if (_isDescriptionFragment(trimmed)) return false;
    if (_isPartialDescriptionFragment(trimmed)) return false;
    if (_isNoiseFragment(trimmed)) return false;
    return RegExp(r'[A-Za-z]').hasMatch(trimmed);
  }

  static bool _rowHasGrade(OcrRow row) =>
      row.fragments.any((f) => _isGradeFragment(f.text));

  static bool _rowHasSubject(OcrRow row) =>
      row.fragments.any((f) => _isSubjectFragment(f.text));

  static bool _isGradeOnlyRow(OcrRow row) =>
      _rowHasGrade(row) && !_rowHasSubject(row);

  static bool _isSubjectOnlyRow(OcrRow row) =>
      _rowHasSubject(row) && !_rowHasGrade(row);

  static bool _isDescriptionOnlyRow(OcrRow row) {
    final meaningful = row.fragments
        .where((f) => !_isNoiseFragment(f.text))
        .toList(growable: false);
    return meaningful.isNotEmpty &&
        meaningful.every(
          (f) =>
              _isDescriptionFragment(f.text) ||
              _isPartialDescriptionFragment(f.text),
        );
  }

  static OcrRow _combineRows(OcrRow primary, OcrRow secondary) {
    final combined = [...primary.fragments, ...secondary.fragments]
      ..sort((a, b) => a.left.compareTo(b.left));
    return _consolidateRowSubjects(OcrRow(List.unmodifiable(combined)));
  }

  /// Joins split subject tokens such as `ADDITIONAL` + `MATHEMATICS` or
  /// `BAHASA` + `INGGERIS` into one fragment for downstream matching.
  static OcrRow _consolidateRowSubjects(OcrRow row) {
    final hasGradeOrDescription = row.fragments.any(
      (f) =>
          _isGradeFragment(f.text) ||
          _isDescriptionFragment(f.text) ||
          _isPartialDescriptionFragment(f.text),
    );
    if (!hasGradeOrDescription) return row;

    final subjectFragments = <OcrFragment>[];
    final otherFragments = <OcrFragment>[];

    for (final fragment in row.fragments) {
      if (_isSubjectFragment(fragment.text)) {
        subjectFragments.add(fragment);
      } else {
        otherFragments.add(fragment);
      }
    }

    if (subjectFragments.length <= 1) {
      return row;
    }

    final combinedSubject = OcrFragment(
      text: subjectFragments.map((f) => f.text.trim()).join(' '),
      top: subjectFragments.map((f) => f.top).reduce((a, b) => a < b ? a : b),
      bottom:
          subjectFragments.map((f) => f.bottom).reduce((a, b) => a > b ? a : b),
      left: subjectFragments.map((f) => f.left).reduce((a, b) => a < b ? a : b),
      right:
          subjectFragments.map((f) => f.right).reduce((a, b) => a > b ? a : b),
    );

    final consolidated = [combinedSubject, ...otherFragments]
      ..sort((a, b) => a.left.compareTo(b.left));

    return OcrRow(List.unmodifiable(consolidated));
  }

  /// Merges split OCR rows where grades/descriptions were separated from their
  /// subject line — common with server-side Tesseract output.
  static List<OcrRow> _mergeOrphanGradeRows(List<OcrRow> rows) {
    if (rows.length < 2) return rows;

    final merged = <OcrRow>[];
    var index = 0;

    while (index < rows.length) {
      final current = rows[index];

      if (index + 1 < rows.length) {
        final next = rows[index + 1];

        if (_isGradeOnlyRow(current) && _isSubjectOnlyRow(next)) {
          merged.add(_combineRows(next, current));
          index += 2;
          continue;
        }

        if (_isSubjectOnlyRow(current) && _isGradeOnlyRow(next)) {
          merged.add(_combineRows(current, next));
          index += 2;
          continue;
        }

        if (_isDescriptionOnlyRow(current) && _isSubjectOnlyRow(next)) {
          merged.add(_combineRows(next, current));
          index += 2;
          continue;
        }

        if (_isSubjectOnlyRow(current) &&
            _isDescriptionOnlyRow(next) &&
            index + 2 < rows.length &&
            _isSubjectOnlyRow(rows[index + 2])) {
          merged.add(_combineRows(rows[index + 2], _combineRows(current, next)));
          index += 3;
          continue;
        }
      }

      merged.add(current);
      index++;
    }

    return merged;
  }

  /// Flattens every [TextLine] in every [TextBlock] into a flat list of
  /// [OcrFragment]s, discarding lines with empty text.
  static List<OcrFragment> _flatten(RecognizedText recognizedText) {
    final List<OcrFragment> result = [];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        final text = line.text.trim();
        if (text.isEmpty) continue;
        result.add(OcrFragment(
          text: text,
          top: box.top,
          bottom: box.bottom,
          left: box.left,
          right: box.right,
        ));
      }
    }
    return result;
  }

  /// Groups a centerY-sorted list of [OcrFragment]s into rows.
  ///
  /// **Algorithm**
  ///
  /// For every fragment, the algorithm searches all existing row groups for
  /// one whose running-average centerY is within the adaptive threshold. If
  /// the closest matching group is within range, the fragment joins it and
  /// that group's running average is updated. If no group is close enough, a
  /// new row group is opened.
  ///
  /// After all fragments are assigned, groups are re-sorted top-to-bottom by
  /// their final average centerY.
  ///
  /// **Why this beats strict vertical-overlap**
  ///
  /// The previous approach required `fragment.top < rowMaxBottom` — a literal
  /// pixel overlap. On a hand-held phone photo with even a 3° tilt, the right
  /// column (grade) sits a few pixels below the left column (subject name),
  /// causing a gap that broke the grouping. The centerY approach is immune to
  /// this because:
  ///   • It measures the midpoint distance, not edge distance.
  ///   • The threshold scales with the document's own line height, so it
  ///     automatically adapts to different zoom levels and camera distances.
  static List<List<OcrFragment>> _groupIntoRows(List<OcrFragment> sorted) {
    if (sorted.isEmpty) return [];

    // Adaptive threshold: a fraction of the average bounding-box height.
    final double avgHeight =
        sorted.map((f) => f.height).reduce((a, b) => a + b) / sorted.length;
    final double threshold = avgHeight * _thresholdFactor;

    final List<List<OcrFragment>> groups = [];
    // Parallel arrays track running sums and counts for cheap average centerY.
    final List<double> centerYSums = [];
    final List<int> counts = [];

    for (final fragment in sorted) {
      int bestGroup = -1;
      double bestDistance = double.infinity;

      for (int i = 0; i < groups.length; i++) {
        final double rowCenterY = centerYSums[i] / counts[i];
        final double distance = (fragment.centerY - rowCenterY).abs();
        if (distance <= threshold && distance < bestDistance) {
          bestDistance = distance;
          bestGroup = i;
        }
      }

      if (bestGroup == -1) {
        // No existing group is close enough — open a new row.
        groups.add([fragment]);
        centerYSums.add(fragment.centerY);
        counts.add(1);
      } else {
        // Join the nearest group and update its running average.
        groups[bestGroup].add(fragment);
        centerYSums[bestGroup] += fragment.centerY;
        counts[bestGroup]++;
      }
    }

    // Re-sort groups top-to-bottom by average centerY.
    final List<int> order = List.generate(groups.length, (i) => i)
      ..sort((a, b) {
        final avgA = centerYSums[a] / counts[a];
        final avgB = centerYSums[b] / counts[b];
        return avgA.compareTo(avgB);
      });

    return order.map((i) => groups[i]).toList(growable: false);
  }
}
