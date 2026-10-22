import 'package:flutter/material.dart';
import '../models/annotation.dart';
import '../services/annotation_service.dart';

class AnnotationPanel extends StatefulWidget {
  final int documentId;
  final int currentPage;

  const AnnotationPanel({
    super.key,
    required this.documentId,
    required this.currentPage,
  });

  @override
  State<AnnotationPanel> createState() => _AnnotationPanelState();
}

class _AnnotationPanelState extends State<AnnotationPanel>
    with SingleTickerProviderStateMixin {
  final _annotationService = AnnotationService();
  late TabController _tabController;
  List<Annotation> _pageAnnotations = [];
  bool _loading = false;

  static const List<Map<String, dynamic>> _highlightColors = [
    {'hex': '#E65A4B', 'color': Color(0xFFE65A4B), 'name': 'Coral Red'},
    {'hex': '#3D3D3F', 'color': Color(0xFF3D3D3F), 'name': 'Dark Charcoal'},
    {'hex': '#FFFF00', 'color': Color(0xFFFFFF00), 'name': 'Yellow'},
    {'hex': '#90EE90', 'color': Color(0xFF90EE90), 'name': 'Green'},
    {'hex': '#ADD8E6', 'color': Color(0xFFADD8E6), 'name': 'Blue'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnnotations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnotations() async {
    setState(() => _loading = true);
    final anns = await _annotationService.fetchForPage(
        widget.documentId, widget.currentPage);
    if (mounted) {
      setState(() {
        _pageAnnotations = anns;
        _loading = false;
      });
    }
  }

  Future<void> _showAddHighlightDialog() async {
    final textController = TextEditingController();
    String selectedHex = _highlightColors.first['hex']!;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text('Add Highlight',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Paste or type selected text...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Highlight Color',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: _highlightColors.map((c) {
                  final hex = c['hex'] as String;
                  final color = c['color'] as Color;
                  final selected = selectedHex == hex;
                  return GestureDetector(
                    onTap: () => setInner(() => selectedHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () async {
                final t = textController.text.trim();
                if (t.isNotEmpty) {
                  await _annotationService.addHighlight(
                    documentId: widget.documentId,
                    pageNumber: widget.currentPage,
                    selectedText: t,
                    colorHex: selectedHex,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadAnnotations();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddNoteDialog({Annotation? existing}) async {
    final textController =
        TextEditingController(text: existing?.noteContent ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: Text(
          existing == null ? 'Add Note' : 'Edit Note',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white),
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Write your note for page ${widget.currentPage + 1}...',
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
            onPressed: () async {
              final t = textController.text.trim();
              if (t.isNotEmpty) {
                if (existing != null) {
                  await _annotationService.updateNote(existing.id!, t);
                } else {
                  await _annotationService.addNote(
                    documentId: widget.documentId,
                    pageNumber: widget.currentPage,
                    noteContent: t,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAnnotations();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnotation(Annotation ann) async {
    await _annotationService.deleteAnnotation(ann.id!);
    await _loadAnnotations();
  }

  @override
  Widget build(BuildContext context) {
    final highlights = _pageAnnotations
        .where((a) => a.type == AnnotationType.highlight)
        .toList();
    final notes =
        _pageAnnotations.where((a) => a.type == AnnotationType.note).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Annotations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Page ${widget.currentPage + 1}',
                    style: const TextStyle(
                        color: Color(0xFFA29BFE), fontSize: 12),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6C63FF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'Highlights (${highlights.length})'),
              Tab(text: 'Notes (${notes.length})'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _AnnotationList(
                        items: highlights,
                        emptyMessage: 'No highlights on this page.',
                        emptyIcon: Icons.highlight_rounded,
                        onDelete: _deleteAnnotation,
                        addButton: ElevatedButton.icon(
                          onPressed: _showAddHighlightDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Highlight'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        scrollController: scrollController,
                      ),
                      _AnnotationList(
                        items: notes,
                        emptyMessage: 'No notes on this page.',
                        emptyIcon: Icons.sticky_note_2_rounded,
                        onDelete: _deleteAnnotation,
                        onEdit: (ann) => _showAddNoteDialog(existing: ann),
                        addButton: ElevatedButton.icon(
                          onPressed: () => _showAddNoteDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Note'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        scrollController: scrollController,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationList extends StatelessWidget {
  final List<Annotation> items;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(Annotation) onDelete;
  final void Function(Annotation)? onEdit;
  final Widget addButton;
  final ScrollController scrollController;

  const _AnnotationList({
    required this.items,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onDelete,
    this.onEdit,
    required this.addButton,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        addButton,
        const SizedBox(height: 16),
        if (items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                children: [
                  Icon(emptyIcon, color: Colors.white12, size: 40),
                  const SizedBox(height: 10),
                  Text(emptyMessage,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ...items.map((ann) => _AnnotationCard(
                annotation: ann,
                onDelete: onDelete,
                onEdit: onEdit,
              )),
      ],
    );
  }
}

class _AnnotationCard extends StatelessWidget {
  final Annotation annotation;
  final void Function(Annotation) onDelete;
  final void Function(Annotation)? onEdit;

  const _AnnotationCard({
    required this.annotation,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlight = annotation.type == AnnotationType.highlight;
    final colorHex = annotation.colorHex;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight 
              ? Color(int.parse(colorHex.replaceFirst('#', '0xFF')))
              : const Color(0xFFFFD700),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHighlight ? Icons.highlight_rounded : Icons.sticky_note_2_rounded,
                size: 16,
                color: isHighlight 
                    ? Color(int.parse(colorHex.replaceFirst('#', '0xFF')))
                    : const Color(0xFFFFD700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHighlight ? 'Highlight' : 'Note',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  color: Colors.white38,
                  onPressed: () => onEdit!(annotation),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 16),
                color: Colors.white38,
                onPressed: () => onDelete(annotation),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isHighlight ? annotation.selectedText ?? '' : annotation.noteContent ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}