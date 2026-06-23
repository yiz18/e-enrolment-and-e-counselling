import 'package:flutter/material.dart';

/// Shared image preview and multi-file browsing for student/admin flows.
class DocumentImagePreview {
  DocumentImagePreview._();

  static void show(BuildContext context, String url,
      {String title = 'Document Preview'}) {
    showDialog<void>(
      context: context,
      builder: (previewContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          height: 480,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        color: Colors.red, size: 48),
                    SizedBox(height: 12),
                    Text('Failed to load image.'),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(previewContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Opens a thumbnail grid for [urls].
  ///
  /// When [onDelete] is provided (student flow), each thumbnail shows a delete
  /// control. Admin flows omit [onDelete].
  static void showFilesSheet(
    BuildContext context, {
    required String title,
    required List<String> urls,
    Future<void> Function(String url)? onDelete,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _DocumentFilesSheet(
        parentContext: context,
        title: title,
        urls: urls,
        onDelete: onDelete,
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text(
          'Are you sure you want to remove this file?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _DocumentFilesSheet extends StatefulWidget {
  const _DocumentFilesSheet({
    required this.parentContext,
    required this.title,
    required this.urls,
    this.onDelete,
  });

  final BuildContext parentContext;
  final String title;
  final List<String> urls;
  final Future<void> Function(String url)? onDelete;

  @override
  State<_DocumentFilesSheet> createState() => _DocumentFilesSheetState();
}

class _DocumentFilesSheetState extends State<_DocumentFilesSheet> {
  late List<String> _urls;
  String? _deletingUrl;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.urls);
  }

  Future<void> _handleDelete(String url) async {
    if (widget.onDelete == null || _deletingUrl != null) return;

    final confirmed =
        await DocumentImagePreview._confirmDelete(widget.parentContext);
    if (!confirmed || !mounted) return;

    setState(() => _deletingUrl = url);

    try {
      await widget.onDelete!(url);
      if (!mounted) return;

      setState(() {
        _urls.remove(url);
        _deletingUrl = null;
      });

      if (_urls.isEmpty && mounted) {
        Navigator.pop(context);
      }

      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(
            content: Text('File deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingUrl = null);

      if (widget.parentContext.mounted) {
        final message = e is Exception ? e.toString() : '$e';
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = widget.onDelete != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_urls.length} file${_urls.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: _urls.isEmpty
                  ? Center(
                      child: Text(
                        'No files',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _urls.length,
                      itemBuilder: (context, index) {
                        final url = _urls[index];
                        final isDeleting = _deletingUrl == url;

                        return Stack(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: isDeleting
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      DocumentImagePreview.show(
                                        widget.parentContext,
                                        url,
                                        title: widget.title,
                                      );
                                    },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (canDelete)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: isDeleting
                                        ? null
                                        : () => _handleDelete(url),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: isDeleting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete_outline,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
