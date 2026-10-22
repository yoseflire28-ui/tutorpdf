import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../core/app_theme.dart';

enum AnnotationTool {
  pen,
  eraser,
  highlighter,
  underline,
  strikethrough,
  textBox,
  stickyNote,
  rectangle,
  circle,
  arrow,
  none,
}

class AnnotationData {
  final AnnotationTool type;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String? text;
  final Rect? bounds;
  final DateTime createdAt;

  AnnotationData({
    required this.type,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.text,
    this.bounds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AnnotationLayer extends StatefulWidget {
  final Size pageSize;
  final List<AnnotationData> annotations;
  final Function(AnnotationData)? onAnnotationAdded;
  final Function(int)? onAnnotationDeleted;
  final Function(List<AnnotationData>)? onAnnotationsUpdated;

  const AnnotationLayer({
    super.key,
    required this.pageSize,
    this.annotations = const [],
    this.onAnnotationAdded,
    this.onAnnotationDeleted,
    this.onAnnotationsUpdated,
  });

  @override
  State<AnnotationLayer> createState() => _AnnotationLayerState();
}

class _AnnotationLayerState extends State<AnnotationLayer> {
  AnnotationTool _currentTool = AnnotationTool.none;
  final List<Offset> _currentStroke = [];
  Color _currentColor = AppTheme.coralAccent;
  double _currentStrokeWidth = 3.0;
  Offset? _startPoint;
  Offset? _endPoint;
  final List<AnnotationData> _localAnnotations = [];

  @override
  void initState() {
    super.initState();
    _localAnnotations.addAll(widget.annotations);
  }

  @override
  void didUpdateWidget(AnnotationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.annotations != widget.annotations) {
      _localAnnotations.clear();
      _localAnnotations.addAll(widget.annotations);
    }
  }

  void _setTool(AnnotationTool tool) {
    setState(() {
      _currentTool = tool;
      _currentStroke.clear();
      _startPoint = null;
      _endPoint = null;
    });
  }

  void _setColor(Color color) {
    setState(() {
      _currentColor = color;
    });
  }

  void _setStrokeWidth(double width) {
    setState(() {
      _currentStrokeWidth = width;
    });
  }

  void _clearAll() {
    setState(() {
      _localAnnotations.clear();
      _currentStroke.clear();
    });
    widget.onAnnotationsUpdated?.call(_localAnnotations);
  }

  void _undoLast() {
    if (_localAnnotations.isNotEmpty) {
      setState(() {
        _localAnnotations.removeLast();
      });
      widget.onAnnotationsUpdated?.call(_localAnnotations);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (_currentTool == AnnotationTool.none) return;

    setState(() {
      _startPoint = details.localPosition;
      _endPoint = details.localPosition;
      
      if (_currentTool == AnnotationTool.pen || 
          _currentTool == AnnotationTool.eraser ||
          _currentTool == AnnotationTool.highlighter) {
        _currentStroke.add(details.localPosition);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_currentTool == AnnotationTool.none) return;

    setState(() {
      _endPoint = details.localPosition;
      
      if (_currentTool == AnnotationTool.pen || 
          _currentTool == AnnotationTool.eraser ||
          _currentTool == AnnotationTool.highlighter) {
        _currentStroke.add(details.localPosition);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_currentTool == AnnotationTool.none || _currentStroke.isEmpty) return;

    final annotation = AnnotationData(
      type: _currentTool,
      points: List.from(_currentStroke),
      color: _currentColor,
      strokeWidth: _currentStrokeWidth,
      bounds: _startPoint != null && _endPoint != null
          ? Rect.fromPoints(_startPoint!, _endPoint!)
          : null,
    );

    setState(() {
      _localAnnotations.add(annotation);
      _currentStroke.clear();
      _startPoint = null;
      _endPoint = null;
    });

    widget.onAnnotationAdded?.call(annotation);
    widget.onAnnotationsUpdated?.call(_localAnnotations);
  }

  void _handleTap(TapUpDetails details) {
    if (_currentTool == AnnotationTool.textBox) {
      _showTextInputDialog(details.localPosition);
    } else if (_currentTool == AnnotationTool.stickyNote) {
      _showStickyNoteDialog(details.localPosition);
    }
  }

  void _showTextInputDialog(Offset position) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Add Text Box',
          style: TextStyle(color: AppTheme.offWhiteText),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.offWhiteText),
          decoration: InputDecoration(
            hintText: 'Enter text',
            hintStyle: TextStyle(
              color: AppTheme.offWhiteText.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppTheme.creamBackground.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.coralAccent),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.offWhiteText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final annotation = AnnotationData(
                  type: AnnotationTool.textBox,
                  points: [position],
                  color: _currentColor,
                  strokeWidth: _currentStrokeWidth,
                  text: controller.text,
                  bounds: Rect.fromCircle(center: position, radius: 50),
                );
                
                setState(() {
                  _localAnnotations.add(annotation);
                });
                
                widget.onAnnotationAdded?.call(annotation);
                widget.onAnnotationsUpdated?.call(_localAnnotations);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralAccent,
              foregroundColor: AppTheme.offWhiteText,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showStickyNoteDialog(Offset position) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Add Sticky Note',
          style: TextStyle(color: AppTheme.offWhiteText),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.offWhiteText),
          decoration: InputDecoration(
            hintText: 'Enter note',
            hintStyle: TextStyle(
              color: AppTheme.offWhiteText.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: Colors.yellow.withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.coralAccent),
            ),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.offWhiteText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final annotation = AnnotationData(
                  type: AnnotationTool.stickyNote,
                  points: [position],
                  color: Colors.yellow,
                  strokeWidth: _currentStrokeWidth,
                  text: controller.text,
                  bounds: Rect.fromCircle(center: position, radius: 80),
                );
                
                setState(() {
                  _localAnnotations.add(annotation);
                });
                
                widget.onAnnotationAdded?.call(annotation);
                widget.onAnnotationsUpdated?.call(_localAnnotations);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralAccent,
              foregroundColor: AppTheme.offWhiteText,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showSignaturePad() {
    showDialog(
      context: context,
      builder: (context) => SignaturePadDialog(
        onSave: (signatureImage) {
          final annotation = AnnotationData(
            type: AnnotationTool.pen,
            points: [],
            color: AppTheme.coralAccent,
            strokeWidth: 2.0,
            text: 'signature',
            bounds: const Rect.fromLTWH(0, 0, 200, 100),
          );
          
          setState(() {
            _localAnnotations.add(annotation);
          });
          
          widget.onAnnotationAdded?.call(annotation);
          widget.onAnnotationsUpdated?.call(_localAnnotations);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onTapUp: _handleTap,
          child: CustomPaint(
            painter: _AnnotationPainter(
              annotations: _localAnnotations,
              currentStroke: _currentStroke,
              currentTool: _currentTool,
              currentColor: _currentColor,
              currentStrokeWidth: _currentStrokeWidth,
              startPoint: _startPoint,
              endPoint: _endPoint,
            ),
            size: widget.pageSize,
          ),
        ),
        _buildToolbar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolButton(
                    icon: Icons.edit,
                    tool: AnnotationTool.pen,
                    tooltip: 'Pen',
                  ),
                  _buildToolButton(
                    icon: Icons.delete_outline,
                    tool: AnnotationTool.eraser,
                    tooltip: 'Eraser',
                  ),
                  _buildToolButton(
                    icon: Icons.highlight,
                    tool: AnnotationTool.highlighter,
                    tooltip: 'Highlighter',
                  ),
                  _buildToolButton(
                    icon: Icons.format_underlined,
                    tool: AnnotationTool.underline,
                    tooltip: 'Underline',
                  ),
                  _buildToolButton(
                    icon: Icons.strikethrough_s,
                    tool: AnnotationTool.strikethrough,
                    tooltip: 'Strikethrough',
                  ),
                  _buildToolButton(
                    icon: Icons.text_fields,
                    tool: AnnotationTool.textBox,
                    tooltip: 'Text Box',
                  ),
                  _buildToolButton(
                    icon: Icons.note,
                    tool: AnnotationTool.stickyNote,
                    tooltip: 'Sticky Note',
                  ),
                  _buildToolButton(
                    icon: Icons.crop_square,
                    tool: AnnotationTool.rectangle,
                    tooltip: 'Rectangle',
                  ),
                  _buildToolButton(
                    icon: Icons.circle_outlined,
                    tool: AnnotationTool.circle,
                    tooltip: 'Circle',
                  ),
                  _buildToolButton(
                    icon: Icons.arrow_forward,
                    tool: AnnotationTool.arrow,
                    tooltip: 'Arrow',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.draw, color: AppTheme.coralAccent),
                    onPressed: _showSignaturePad,
                    tooltip: 'Signature',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.undo, color: AppTheme.offWhiteText),
                    onPressed: _undoLast,
                    tooltip: 'Undo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.offWhiteText),
                    onPressed: _clearAll,
                    tooltip: 'Clear All',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Color: ',
                  style: TextStyle(color: AppTheme.offWhiteText),
                ),
                ...[
                  AppTheme.coralAccent,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                  AppTheme.offWhiteText,
                ].map((color) => GestureDetector(
                  onTap: () => _setColor(color),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _currentColor == color 
                            ? AppTheme.offWhiteText 
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )),
                const SizedBox(width: 16),
                const Text(
                  'Size: ',
                  style: TextStyle(color: AppTheme.offWhiteText),
                ),
                Slider(
                  value: _currentStrokeWidth,
                  min: 1.0,
                  max: 10.0,
                  onChanged: _setStrokeWidth,
                  activeColor: AppTheme.coralAccent,
                  label: _currentStrokeWidth.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required AnnotationTool tool,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(
          icon,
          color: _currentTool == tool 
              ? AppTheme.coralAccent 
              : AppTheme.offWhiteText,
        ),
        onPressed: () => _setTool(_currentTool == tool ? AnnotationTool.none : tool),
        tooltip: tooltip,
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<AnnotationData> annotations;
  final List<Offset> currentStroke;
  final AnnotationTool currentTool;
  final Color currentColor;
  final double currentStrokeWidth;
  final Offset? startPoint;
  final Offset? endPoint;

  _AnnotationPainter({
    required this.annotations,
    required this.currentStroke,
    required this.currentTool,
    required this.currentColor,
    required this.currentStrokeWidth,
    this.startPoint,
    this.endPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintAnnotations(canvas);
    _paintCurrentStroke(canvas);
  }

  void _paintAnnotations(Canvas canvas) {
    for (final annotation in annotations) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = annotation.color
        ..strokeWidth = annotation.strokeWidth;

      switch (annotation.type) {
        case AnnotationTool.pen:
          _paintPath(canvas, annotation, paint);
          break;
        case AnnotationTool.highlighter:
          paint.style = PaintingStyle.fill;
          paint.color = annotation.color.withValues(alpha: 0.3);
          _paintPath(canvas, annotation, paint);
          break;
        case AnnotationTool.underline:
          _paintUnderline(canvas, annotation, paint);
          break;
        case AnnotationTool.strikethrough:
          _paintStrikethrough(canvas, annotation, paint);
          break;
        case AnnotationTool.rectangle:
          _paintRectangle(canvas, annotation, paint);
          break;
        case AnnotationTool.circle:
          _paintCircle(canvas, annotation, paint);
          break;
        case AnnotationTool.arrow:
          _paintArrow(canvas, annotation, paint);
          break;
        case AnnotationTool.textBox:
          _paintTextBox(canvas, annotation);
          break;
        case AnnotationTool.stickyNote:
          _paintStickyNote(canvas, annotation);
          break;
        case AnnotationTool.eraser:
        case AnnotationTool.none:
          break;
      }
    }
  }

  void _paintPath(Canvas canvas, AnnotationData annotation, Paint paint) {
    if (annotation.points.length < 2) return;
    
    final path = Path();
    path.moveTo(annotation.points.first.dx, annotation.points.first.dy);
    
    for (int i = 1; i < annotation.points.length; i++) {
      path.lineTo(annotation.points[i].dx, annotation.points[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }

  void _paintUnderline(Canvas canvas, AnnotationData annotation, Paint paint) {
    if (annotation.points.isEmpty) return;
    
    final points = annotation.points;
    final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    
    paint.strokeWidth = 2.0;
    canvas.drawLine(
      Offset(points.first.dx, maxY),
      Offset(points.last.dx, maxY),
      paint,
    );
  }

  void _paintStrikethrough(Canvas canvas, AnnotationData annotation, Paint paint) {
    if (annotation.points.isEmpty) return;
    
    final points = annotation.points;
    final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    final midY = (minY + maxY) / 2;
    
    paint.strokeWidth = 2.0;
    canvas.drawLine(
      Offset(points.first.dx, midY),
      Offset(points.last.dx, midY),
      paint,
    );
  }

  void _paintRectangle(Canvas canvas, AnnotationData annotation, Paint paint) {
    if (annotation.bounds == null) return;
    
    canvas.drawRect(annotation.bounds!, paint);
  }

  void _paintCircle(Canvas canvas, AnnotationData annotation, Paint paint) {
    if (annotation.bounds == null) return;
    
    final center = annotation.bounds!.center;
    final radius = math.min(annotation.bounds!.width / 2, annotation.bounds!.height / 2);
    
    canvas.drawCircle(center, radius, paint);
  }

  void _paintArrow(Canvas canvas, AnnotationData annotation, Paint paint) {
    if (annotation.points.length < 2) return;
    
    final start = annotation.points.first;
    final end = annotation.points.last;
    
    canvas.drawLine(start, end, paint);
    
    const arrowSize = 10.0;
    final angle = (end - start).direction;
    
    final arrowPath = Path();
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );
    
    canvas.drawPath(arrowPath, paint);
  }

  void _paintTextBox(Canvas canvas, AnnotationData annotation) {
    if (annotation.text == null || annotation.bounds == null) return;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: annotation.text,
        style: TextStyle(
          color: annotation.color,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, annotation.bounds!.topLeft);
  }

  void _paintStickyNote(Canvas canvas, AnnotationData annotation) {
    if (annotation.text == null || annotation.bounds == null) return;
    
    final bgPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(annotation.bounds!, const Radius.circular(8)),
      bgPaint,
    );
    
    final borderPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(annotation.bounds!, const Radius.circular(8)),
      borderPaint,
    );
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: annotation.text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: annotation.bounds!.width - 16);
    textPainter.paint(
      canvas,
      Offset(
        annotation.bounds!.left + 8,
        annotation.bounds!.top + 8,
      ),
    );
  }

  void _paintCurrentStroke(Canvas canvas) {
    if (currentStroke.isEmpty) return;
    
    final paint = Paint()
      ..style = currentTool == AnnotationTool.highlighter 
          ? PaintingStyle.fill 
          : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = currentTool == AnnotationTool.highlighter 
          ? currentColor.withValues(alpha: 0.3) 
          : currentColor
      ..strokeWidth = currentStrokeWidth;

    if (currentTool == AnnotationTool.pen || 
        currentTool == AnnotationTool.highlighter ||
        currentTool == AnnotationTool.eraser) {
      final path = Path();
      path.moveTo(currentStroke.first.dx, currentStroke.first.dy);
      
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      
      canvas.drawPath(path, paint);
    } else if (startPoint != null && endPoint != null) {
      switch (currentTool) {
        case AnnotationTool.rectangle:
          canvas.drawRect(
            Rect.fromPoints(startPoint!, endPoint!),
            paint,
          );
          break;
        case AnnotationTool.circle:
          final center = startPoint!;
          final radius = (endPoint! - startPoint!).distance;
          canvas.drawCircle(center, radius, paint);
          break;
        case AnnotationTool.arrow:
          canvas.drawLine(startPoint!, endPoint!, paint);
          
          const arrowSize = 10.0;
          final angle = (endPoint! - startPoint!).direction;
          
          final arrowPath = Path();
          arrowPath.moveTo(endPoint!.dx, endPoint!.dy);
          arrowPath.lineTo(
            endPoint!.dx - arrowSize * math.cos(angle - math.pi / 6),
            endPoint!.dy - arrowSize * math.sin(angle - math.pi / 6),
          );
          arrowPath.moveTo(endPoint!.dx, endPoint!.dy);
          arrowPath.lineTo(
            endPoint!.dx - arrowSize * math.cos(angle + math.pi / 6),
            endPoint!.dy - arrowSize * math.sin(angle + math.pi / 6),
          );
          
          canvas.drawPath(arrowPath, paint);
          break;
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.annotations != annotations ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth ||
        oldDelegate.startPoint != startPoint ||
        oldDelegate.endPoint != endPoint;
  }
}

class SignaturePadDialog extends StatefulWidget {
  final Function(ui.Image?) onSave;

  const SignaturePadDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<Offset> _signaturePoints = [];
  final GlobalKey _signatureKey = GlobalKey();

  void _clearSignature() {
    setState(() {
      _signaturePoints.clear();
    });
  }

  void _handlePanStart(DragStartDetails details) {
    final RenderBox? box = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final localPosition = box.globalToLocal(details.globalPosition);
      setState(() {
        _signaturePoints.add(localPosition);
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final RenderBox? box = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final localPosition = box.globalToLocal(details.globalPosition);
      setState(() {
        _signaturePoints.add(localPosition);
      });
    }
  }

  void _saveSignature() async {
    try {
      final RenderRepaintBoundary? boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        widget.onSave(image);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.charcoalCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Draw Signature',
        style: TextStyle(color: AppTheme.offWhiteText),
      ),
      content: SizedBox(
        width: 300,
        height: 200,
        child: GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          child: RepaintBoundary(
            key: _signatureKey,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.creamBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.coralAccent),
              ),
              child: CustomPaint(
                painter: _SignaturePainter(points: _signaturePoints),
                size: const Size(300, 200),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _clearSignature,
          child: const Text(
            'Clear',
            style: TextStyle(color: AppTheme.offWhiteText),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.offWhiteText),
          ),
        ),
        ElevatedButton(
          onPressed: _signaturePoints.isNotEmpty ? _saveSignature : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.coralAccent,
            foregroundColor: AppTheme.offWhiteText,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final paint = Paint()
      ..color = AppTheme.coralAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
