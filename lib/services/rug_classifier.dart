import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// On-device prayer-rug verification.
///
/// Kadd deliberately does not depend on a checked-in TFLite binary. The
/// generic ML Kit image-labeling model is available on supported Android
/// devices and gives us a local, offline visual signal such as "rug",
/// "carpet" or "mat". We use a conservative confidence gate in the scan
/// screen and fail closed when the classifier cannot produce a signal.
class RugClassifier {
  ImageLabeler? _labeler;

  bool get isLoaded => _labeler != null;

  Future<void> load() async {
    dispose();
    try {
      _labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.0),
      );
    } catch (_) {
      _labeler = null;
    }
  }

  /// Returns the strongest confidence that the image contains a floor-rug
  /// like object. Returns 0.0 when no supported label is produced.
  Future<double> classify(String imagePath) async {
    final labeler = _labeler;
    if (labeler == null) return 0.0;

    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      var best = 0.0;
      for (final label in labels) {
        final normalized = label.label.toLowerCase().trim();
        final isRugLike = normalized.contains('rug') ||
            normalized.contains('carpet') ||
            normalized.contains('mat');
        if (isRugLike && label.confidence > best) {
          best = label.confidence.clamp(0.0, 1.0);
        }
      }
      return best;
    } catch (_) {
      return 0.0;
    }
  }

  /// Kept as a small utility for callers that may later use a bundled model.
  Future<String> copyAssetToFile(String assetPath) async {
    final dir = await getApplicationSupportDirectory();
    final filePath = path.join(dir.path, path.basename(assetPath));
    final file = File(filePath);
    return file.path;
  }

  void dispose() {
    _labeler?.close();
    _labeler = null;
  }
}
