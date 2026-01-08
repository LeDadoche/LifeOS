import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Modèle représentant un trait avec sa propre couleur et épaisseur
class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  /// Convertit le trait en JSON pour sauvegarde
  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.value,
        'strokeWidth': strokeWidth,
        'isEraser': isEraser,
      };

  /// Crée un trait depuis JSON
  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      points: (json['points'] as List)
          .map((p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      isEraser: json['isEraser'] as bool? ?? false,
    );
  }
}

/// Modèle complet du croquis avec tous les traits
class SketchData {
  final List<Stroke> strokes;
  final int width;
  final int height;

  SketchData({
    required this.strokes,
    this.width = 0,
    this.height = 0,
  });

  /// Convertit en JSON string pour stockage
  String toJsonString() => jsonEncode({
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'width': width,
        'height': height,
        'version': 2,
      });

  /// Crée depuis JSON string
  factory SketchData.fromJsonString(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (json.containsKey('strokes')) {
        return SketchData(
          strokes: (json['strokes'] as List)
              .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
              .toList(),
          width: json['width'] as int? ?? 0,
          height: json['height'] as int? ?? 0,
        );
      }

      return SketchData(strokes: []);
    } catch (e) {
      debugPrint('❌ [Sketch] Erreur parsing: $e');
      return SketchData(strokes: []);
    }
  }

  bool get isEmpty => strokes.isEmpty;
}

/// Painter personnalisé pour dessiner les traits
class SketchPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  SketchPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner tous les traits terminés
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Dessiner le trait en cours
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth;

    if (stroke.isEraser) {
      // Gomme : dessiner en blanc (couleur du fond)
      paint.color = Colors.white;
    } else {
      paint.color = stroke.color;
    }

    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      canvas.drawCircle(
          point, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
    } else {
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke;
  }
}

/// Écran de dessin/croquis pour les notes
class SketchScreen extends StatefulWidget {
  /// Données du croquis existant (JSON ou null)
  final String? existingSketchData;

  const SketchScreen({super.key, this.existingSketchData});

  @override
  State<SketchScreen> createState() => _SketchScreenState();
}

class _SketchScreenState extends State<SketchScreen> {
  final List<Stroke> _strokes = [];
  final List<Stroke> _undoneStrokes = [];
  Stroke? _currentStroke;

  // Toujours démarrer avec STYLO NOIR
  Color _penColor = Colors.black;
  double _penStrokeWidth = 4.0;
  bool _isEraserMode = false;

  final GlobalKey _canvasKey = GlobalKey();

  // Couleurs de base (5 couleurs + bouton personnalisé)
  final List<Color> _baseColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  // Couleur grise neutre pour les indicateurs de taille
  static const Color _neutralGray = Color(0xFF333333);

  // Épaisseurs disponibles
  final List<double> _availableWidths = [2.0, 4.0, 6.0, 10.0, 16.0];

  @override
  void initState() {
    super.initState();
    _loadExistingSketch();
    // Forcer le mode STYLO NOIR à l'ouverture
    _penColor = Colors.black;
    _isEraserMode = false;
  }

  /// Charge un croquis existant si disponible
  void _loadExistingSketch() {
    if (widget.existingSketchData != null &&
        widget.existingSketchData!.isNotEmpty) {
      try {
        if (widget.existingSketchData!.startsWith('{')) {
          final sketchData =
              SketchData.fromJsonString(widget.existingSketchData!);
          setState(() {
            _strokes.addAll(sketchData.strokes);
          });
          debugPrint('✅ [Sketch] Chargé ${_strokes.length} traits');
        } else {
          debugPrint(
              '⚠️ [Sketch] Ancien format base64, traits non récupérables');
        }
      } catch (e) {
        debugPrint('❌ [Sketch] Erreur chargement: $e');
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);

    debugPrint(
        '🖌️ [Sketch] Début trait - Gomme: $_isEraserMode, Couleur: $_penColor');

    setState(() {
      _currentStroke = Stroke(
        points: [localPosition],
        color: _penColor,
        strokeWidth: _penStrokeWidth,
        isEraser: _isEraserMode,
      );
      _undoneStrokes.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      _currentStroke = Stroke(
        points: [..._currentStroke!.points, localPosition],
        color: _currentStroke!.color,
        strokeWidth: _currentStroke!.strokeWidth,
        isEraser: _currentStroke!.isEraser,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _undoneStrokes.add(_strokes.removeLast());
      });
    }
  }

  void _redo() {
    if (_undoneStrokes.isNotEmpty) {
      setState(() {
        _strokes.add(_undoneStrokes.removeLast());
      });
    }
  }

  void _clear() {
    setState(() {
      _undoneStrokes.addAll(_strokes);
      _strokes.clear();
    });
  }

  /// Ouvre le sélecteur de couleur avancé (spectre complet)
  void _openColorPicker() {
    Color tempColor = _penColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une couleur'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (color) {
              tempColor = color;
            },
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hueWheel,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _penColor = tempColor;
                _isEraserMode = false; // Retour au mode stylo
              });
              Navigator.of(context).pop();
            },
            child: const Text('Choisir'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndReturn() async {
    if (_strokes.isEmpty) {
      Navigator.of(context).pop(null);
      return;
    }

    try {
      final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final size = box?.size ?? const Size(400, 400);

      final sketchData = SketchData(
        strokes: _strokes,
        width: size.width.toInt(),
        height: size.height.toInt(),
      );

      final imageData = await _generatePngImage(size);

      final result = {
        'json': sketchData.toJsonString(),
        'image': imageData,
      };

      Navigator.of(context).pop(jsonEncode(result));
    } catch (e) {
      debugPrint('❌ [Sketch] Erreur export: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<String?> _generatePngImage(Size size) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white,
      );

      final painter = SketchPainter(strokes: _strokes);
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final image =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('❌ [Sketch] Erreur génération image: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Croquis'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Effacer tout',
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Annuler',
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Rétablir',
            onPressed: _undoneStrokes.isEmpty ? null : _redo,
          ),
          FilledButton.icon(
            onPressed: _saveAndReturn,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Enregistrer'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barre d'outils
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Toggle Gomme / Stylo
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.edit, size: 18),
                        label: Text('Stylo'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.auto_fix_high, size: 18),
                        label: Text('Gomme'),
                      ),
                    ],
                    selected: {_isEraserMode},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _isEraserMode = selected.first;
                        debugPrint('🖌️ [Sketch] Mode gomme: $_isEraserMode');
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Sélecteur de couleur (visible seulement en mode stylo)
                  if (!_isEraserMode) ...[
                    const Text('Couleur: ', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    // Couleurs de base
                    ...(_baseColors.map((color) => GestureDetector(
                          onTap: () => setState(() => _penColor = color),
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _penColor == color
                                    ? colorScheme.primary
                                    : Colors.grey.shade300,
                                width: _penColor == color ? 3 : 1,
                              ),
                              boxShadow: _penColor == color
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 4,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ))),
                    // Bouton "+" pour couleur personnalisée
                    GestureDetector(
                      onTap: _openColorPicker,
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          gradient: const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: !_baseColors.contains(_penColor)
                                ? colorScheme.primary
                                : Colors.grey.shade300,
                            width: !_baseColors.contains(_penColor) ? 3 : 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.add, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  // Sélecteur d'épaisseur avec gris neutre
                  Text(
                    _isEraserMode ? 'Taille: ' : 'Épaisseur: ',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  ...(_availableWidths.map((width) => GestureDetector(
                        onTap: () => setState(() => _penStrokeWidth = width),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _penStrokeWidth == width
                                ? colorScheme.primaryContainer
                                : colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _penStrokeWidth == width
                                  ? colorScheme.primary
                                  : colorScheme.outline.withOpacity(0.3),
                              width: _penStrokeWidth == width ? 2 : 1,
                            ),
                            boxShadow: _penStrokeWidth == width
                                ? [
                                    BoxShadow(
                                      color:
                                          colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 4,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Container(
                              width: width.clamp(4, 16),
                              height: width.clamp(4, 16),
                              decoration: const BoxDecoration(
                                color: _neutralGray, // Gris neutre toujours
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ))),
                ],
              ),
            ),
          ),

          // Canvas de dessin
          Expanded(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: ClipRect(
                child: Container(
                  key: _canvasKey,
                  color: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                  child: CustomPaint(
                    painter: SketchPainter(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
