import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Wraps ML Kit's Image Labeling API with a custom local model trained on
/// prayer-rug vs. not-prayer-rug photos (see assets/models/README.md for
/// how to produce one, e.g. via Google's Teachable Machine for a fast first
/// version).
///
/// Uses google_mlkit_image_labeling's LocalLabelerOptions rather than the
/// tflite_flutter package — see pubspec.yaml's comment on that dependency
/// for why. ML Kit's native runtime handles the model's input format
/// (float32 vs. quantized) internally, so this class doesn't need to branch
/// on that the way a raw TFLite wrapper would.
class RugClassifier {
  ImageLabeler? _labeler;
  bool _rugLabelIsPositive = true; // flipped if labels.txt lists rug second

  bool get isLoaded => _labeler != null;

  /// Call once (e.g. in RugScanScreen.initState). ML Kit's local labeler
  /// needs a real file path, not an asset URI, so the bundled asset is
  /// copied to the app's support directory on first load.
  Future<void> load({
    String modelAsset = 'assets/models/rug_classifier.tflite',
    String labelsAsset = 'assets/models/labels.txt',
  }) async {
    try {
      final modelPath = await _copyAssetToFile(modelAsset);
      _labeler = ImageLabeler(
        options: LocalLabelerOptions(
          modelPath: modelPath,
          confidenceThreshold: 0.0, // we apply our own gate in classify()
        ),
      );
    } catch (e) {
      // Model not bundled yet — expected until assets/models/README.md's
      // training plan is carried out. isLoaded==false means classify()
      // fails closed, same as before.
      _labeler = null;
      return;
    }

    try {
      final raw = await rootBundle.loadString(labelsAsset);
      final labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .map((l) => l.contains(' ') ? l.substring(l.indexOf(' ') + 1) : l)
          .toList();
      // Teachable Machine assigns label indices in training order — we
      // just need to know whether "rug" was class 0 or class 1, since
      // ML Kit returns each label by name already (no index juggling
      // needed at inference time the way raw TFLite output requires).
      final rugIndex = labels.indexWhere((l) => l.toLowerCase().contains('rug'));
      _rugLabelIsPositive = rugIndex != 1; // default true unless rug is index 1 named oddly
    } catch (e) {
      // Fall back to assuming a label literally called "rug" exists.
    }
  }

  Future<String> _copyAssetToFile(String assetPath) async {
    final dir = await getApplicationSupportDirectory();
    final filePath = path.join(dir.path, path.basename(assetPath));
    final file = File(filePath);
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    return filePath;
  }

  /// Returns the model's confidence (0.0–1.0) that the photo at [imagePath]
  /// shows a prayer rug. Returns 0.0 if no model is loaded, so callers fail
  /// closed by default rather than accidentally unlocking on a missing model.
  Future<double> classify(String imagePath) async {
    if (_labeler == null) return 0.0;

    final inputImage = InputImage.fromFilePath(imagePath);
    final labels = await _labeler!.processImage(inputImage);

    for (final label in labels) {
      if (label.label.toLowerCase().contains('rug')) {
        return label.confidence.clamp(0.0, 1.0);
      }
    }
    // No "rug" label came back above the labeler's internal threshold —
    // treat as high-confidence "not a rug".
    return 0.0;
  }

  void dispose() {
    _labeler?.close();
    _labeler = null;
  }
}
