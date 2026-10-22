import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

class BookmarkSidebar extends StatefulWidget {
  final int documentId;
  final int currentPage;
  final Function(int)? onPageSelected;

  const BookmarkSidebar({
    super.key,
    required this.documentId,
    required this.currentPage,
    this.onPageSelected,
  });

  @override
  State<BookmarkSidebar> createState() => _BookmarkSidebarState();
}

class _BookmarkSidebarState extends State<BookmarkSidebar> {
  final _bookmarkService = BookmarkService();
  List<Bookmark> _bookmarks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _loading = true);
    final bms = await _bookmarkService.fetchForDocument(widget.documentId);
    if (mounted) {
      setState(() {
        _bookmarks = bms;
        _loading = false;
      });
    }
  }

  Future<void> _addBookmark() async {
    await _bookmarkService.addBookmark(
      documentId: widget.documentId,
      pageNumber: widget.currentPage,
      label: 'Page ${widget.currentPage + 1}',
    );
    await _loadBookmarks();
  }

  Future<void> _deleteBookmark(Bookmark bm) async {
    await _bookmarkService.deleteBookmark(bm.id!);
    await _loadBookmarks();
  }

  Future<void> _editBookmark(Bookmark bm) async {
    final controller = TextEditingController(text: bm.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text('Edit Bookmark',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Bookmark label',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F1117),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _bookmarkService.updateBookmark(bm.id!, result);
      await _loadBookmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF1A1D2E),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: Color(0xFF6C63FF)),
                const SizedBox(width: 12),
                const Text(
                  'Bookmarks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  color: const Color(0xFF6C63FF),
                  onPressed: _addBookmark,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _bookmarks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border_rounded,
                                color: Colors.white24, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'No bookmarks yet',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _bookmarks.length,
                        itemBuilder: (_, i) {
                          final bm = _bookmarks[i];
                          final isCurrent = bm.pageNumber == widget.currentPage;
                          return ListTile(
                            leading: Icon(
                              Icons.bookmark_rounded,
                              color: isCurrent
                                  ? const Color(0xFF6C63FF)
                                  : Colors.white38,
                              size: 20,
                            ),
                            title: Text(
                              bm.label ?? 'Page ${bm.pageNumber + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFF6C63FF)
                                    : Colors.white70,
                                fontWeight:
                                    isCurrent ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              'Page ${bm.pageNumber + 1}',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 16),
                                  color: Colors.white38,
                                  onPressed: () => _editBookmark(bm),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, size: 16),
                                  color: Colors.white38,
                                  onPressed: () => _deleteBookmark(bm),
                                ),
                              ],
                            ),
                            onTap: () {
                              widget.onPageSelected?.call(bm.pageNumber);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}