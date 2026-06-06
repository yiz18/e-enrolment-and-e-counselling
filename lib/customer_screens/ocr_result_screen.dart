import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ocr_post_processor.dart';

class OcrResultScreen extends StatelessWidget {
  final OcrStructuredResult structuredResult;

  const OcrResultScreen({super.key, required this.structuredResult});

  @override
  Widget build(BuildContext context) {
    final int rowCount = structuredResult.rows.length;
    final String plainText = structuredResult.plainText;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("OCR Result"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Copy all text",
            icon: const Icon(Icons.copy),
            onPressed: () => _copyToClipboard(context, plainText),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(rowCount: rowCount),
                const SizedBox(height: 12),
                _StructuredRowsCard(rows: structuredResult.rows),
                const SizedBox(height: 20),
                _ActionButtons(
                  onCopy: () => _copyToClipboard(context, plainText),
                  onBack: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Text copied to clipboard")),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int rowCount;

  const _SectionHeader({required this.rowCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.text_fields, color: Colors.blueAccent),
        const SizedBox(width: 8),
        const Text(
          "Extracted Text",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Text(
          "$rowCount row${rowCount == 1 ? '' : 's'} detected",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}

class _StructuredRowsCard extends StatelessWidget {
  final List<OcrRow> rows;

  const _StructuredRowsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.asMap().entries.map((entry) {
          final int index = entry.key;
          final OcrRow row = entry.value;
          return _OcrRowTile(
            rowIndex: index,
            row: row,
            isLast: index == rows.length - 1,
          );
        }).toList(),
      ),
    );
  }
}

class _OcrRowTile extends StatelessWidget {
  final int rowIndex;
  final OcrRow row;
  final bool isLast;

  const _OcrRowTile({
    required this.rowIndex,
    required this.row,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row index badge
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 1, right: 10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "${rowIndex + 1}",
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Fragments as chips
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: row.fragments.map((fragment) {
                  return _FragmentChip(text: fragment.text);
                }).toList(),
              ),
            ),
          ],
        ),
        if (!isLast)
          const Divider(height: 16, thickness: 0.5, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}

class _FragmentChip extends StatelessWidget {
  final String text;

  const _FragmentChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onBack;

  const _ActionButtons({required this.onCopy, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy),
            label: const Text("Copy to Clipboard"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back to Upload"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
