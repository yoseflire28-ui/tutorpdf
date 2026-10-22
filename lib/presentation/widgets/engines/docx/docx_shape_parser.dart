import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import '../../../../core/utils/ooxml_color_parser.dart';

/// DOCX Shape Parser
/// Parses VML (<v:shape>) and DrawingML (<w:drawing>) nodes to extract shape properties.
/// Converts shape data to Flutter widgets for native rendering.
class DocxShapeParser {
  /// Convert hex color string to Flutter Color object
  static Color hexToColor(String hexColor) {
    return OoxmlColorParser.parse(hexColor, defaultColor: Colors.transparent);
  }

  /// Parse VML shape (<v:shape>) and extract style dimensions
  static Map<String, dynamic> parseVmlShape(XmlElement shape) {
    final result = <String, dynamic>{};
    
    // Extract style attribute
    final style = shape.getAttribute('style') ?? '';
    final styleParts = style.split(';');
    
    for (var part in styleParts) {
      final trimmed = part.trim();
      if (trimmed.contains(':')) {
        final keyValue = trimmed.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();
          result[key] = value;
        }
      }
    }
    
    // Extract fill color
    final fillcolor = shape.getAttribute('fillcolor');
    if (fillcolor != null) {
      result['fillColor'] = hexToColor(fillcolor);
    }
    
    // Extract stroke color
    final strokecolor = shape.getAttribute('strokecolor');
    if (strokecolor != null) {
      result['strokeColor'] = hexToColor(strokecolor);
    }
    
    // Extract stroke weight
    final strokeweight = shape.getAttribute('strokeweight');
    if (strokeweight != null) {
      result['strokeWeight'] = double.tryParse(strokeweight.replaceAll('pt', '')) ?? 1.0;
    }
    
    // Extract width and height from style
    if (result.containsKey('width')) {
      final widthStr = result['width'].toString().replaceAll('px', '').replaceAll('pt', '');
      result['width'] = double.tryParse(widthStr) ?? 0.0;
    }
    if (result.containsKey('height')) {
      final heightStr = result['height'].toString().replaceAll('px', '').replaceAll('pt', '');
      result['height'] = double.tryParse(heightStr) ?? 0.0;
    }
    
    // Extract position from style
    if (result.containsKey('left')) {
      final leftStr = result['left'].toString().replaceAll('px', '').replaceAll('pt', '');
      result['x'] = double.tryParse(leftStr) ?? 0.0;
    }
    if (result.containsKey('top')) {
      final topStr = result['top'].toString().replaceAll('px', '').replaceAll('pt', '');
      result['y'] = double.tryParse(topStr) ?? 0.0;
    }
    
    // Extract shape type
    result['type'] = shape.getAttribute('type') ?? 'rect';
    
    return result;
  }

  /// Parse DrawingML shape (<w:drawing>) and extract style dimensions
  static Map<String, dynamic> parseDrawingShape(XmlElement drawing) {
    final result = <String, dynamic>{};
    
    // Parse inline shapes
    final inline = drawing.getElement('wp:inline');
    if (inline != null) {
      final extent = inline.getElement('wp:extent');
      if (extent != null) {
        final cx = extent.getAttribute('cx');
        final cy = extent.getAttribute('cy');
        
        if (cx != null && cy != null) {
          result['width'] = (double.tryParse(cx) ?? 0) / 12700; // EMU to pixels
          result['height'] = (double.tryParse(cy) ?? 0) / 12700;
        }
      }
      
      final graphic = inline.getElement('a:graphic');
      if (graphic != null) {
        final graphicData = graphic.getElement('a:graphicData');
        if (graphicData != null) {
          final pic = graphicData.getElement('pic:pic');
          if (pic != null) {
            result['type'] = 'picture';
            final blip = pic.getElement('pic:blipFill')?.getElement('a:blip');
            if (blip != null) {
              result['embedId'] = blip.getAttribute('r:embed');
            }
          }
        }
      }
    }
    
    // Parse anchored shapes
    final anchor = drawing.getElement('wp:anchor');
    if (anchor != null) {
      final extent = anchor.getElement('wp:extent');
      if (extent != null) {
        final cx = extent.getAttribute('cx');
        final cy = extent.getAttribute('cy');
        
        if (cx != null && cy != null) {
          result['width'] = (double.tryParse(cx) ?? 0) / 12700;
          result['height'] = (double.tryParse(cy) ?? 0) / 12700;
        }
      }
      
      final positionH = anchor.getElement('wp:positionH');
      final positionV = anchor.getElement('wp:positionV');
      
      if (positionH != null) {
        final posOffset = positionH.getElement('wp:posOffset')?.getAttribute('w:val');
        if (posOffset != null) {
          result['x'] = (double.tryParse(posOffset) ?? 0) / 12700;
        }
      }
      
      if (positionV != null) {
        final posOffset = positionV.getElement('wp:posOffset')?.getAttribute('w:val');
        if (posOffset != null) {
          result['y'] = (double.tryParse(posOffset) ?? 0) / 12700;
        }
      }
      
      final graphic = anchor.getElement('a:graphic');
      if (graphic != null) {
        final graphicData = graphic.getElement('a:graphicData');
        if (graphicData != null) {
          final pic = graphicData.getElement('pic:pic');
          if (pic != null) {
            result['type'] = 'picture';
            final blip = pic.getElement('pic:blipFill')?.getElement('a:blip');
            if (blip != null) {
              result['embedId'] = blip.getAttribute('r:embed');
            }
          }
        }
      }
    }
    
    return result;
  }

  /// Parse all shapes from a paragraph
  static List<Map<String, dynamic>> parseParagraphShapes(XmlElement paragraph) {
    final shapes = <Map<String, dynamic>>[];
    
    // Parse VML shapes
    for (var shape in paragraph.findAllElements('v:shape')) {
      shapes.add(parseVmlShape(shape));
    }
    
    // Parse VML rectangles
    for (var rect in paragraph.findAllElements('v:rect')) {
      final rectData = parseVmlShape(rect);
      rectData['type'] = 'rect';
      shapes.add(rectData);
    }
    
    // Parse DrawingML shapes
    for (var drawing in paragraph.findAllElements('w:drawing')) {
      shapes.add(parseDrawingShape(drawing));
    }
    
    return shapes;
  }

  /// Build Flutter widget from shape data
  static Widget buildShapeWidget(Map<String, dynamic> shapeData, bool isDarkMode) {
    final type = shapeData['type'] as String? ?? 'rect';
    final width = shapeData['width'] as double? ?? 100.0;
    final height = shapeData['height'] as double? ?? 50.0;
    final fillColor = shapeData['fillColor'] as Color?;
    final strokeColor = shapeData['strokeColor'] as Color?;
    final strokeWeight = shapeData['strokeWeight'] as double? ?? 1.0;
    final x = shapeData['x'] as double? ?? 0.0;
    final y = shapeData['y'] as double? ?? 0.0;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fillColor ?? (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          border: strokeColor != null
              ? Border.all(
                  color: strokeColor,
                  width: strokeWeight,
                )
              : null,
          borderRadius: type == 'oval' || type == 'ellipse'
              ? BorderRadius.circular(width / 2)
              : BorderRadius.zero,
        ),
      ),
    );
  }

  /// Build list of Flutter widgets from shape data list
  static List<Widget> buildShapeWidgets(List<Map<String, dynamic>> shapes, bool isDarkMode) {
    return shapes.map((shape) => buildShapeWidget(shape, isDarkMode)).toList();
  }
}
