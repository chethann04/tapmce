

/// Utility for extracting clean, human-readable filenames from storage URLs.
class FileNameExtractor {
  FileNameExtractor._();

  /// Extracts a clean filename from a Supabase Storage URL.
  ///
  /// Handles:
  /// - Signed URLs with query params (e.g. `?token=eyJ...`)
  /// - URL-encoded characters (e.g. `%20` → space)
  /// - Full path extraction (e.g. `resumes/user123/CV.pdf?token=...` → `CV.pdf`)
  ///
  /// Returns a fallback if extraction fails.
  static String extract(String url, {String fallback = 'Resume'}) {
    try {
      // Remove query parameters
      final cleanUrl = url.split('?').first;

      // Get the last path segment (the filename)
      final segments = cleanUrl.split('/');
      if (segments.isEmpty) return fallback;

      var filename = segments.last;

      // Decode URL-encoded characters (e.g. %20 → space)
      filename = Uri.decodeComponent(filename);

      // Validate it looks like a filename
      if (filename.isEmpty || filename == '/' || filename == '.') {
        return fallback;
      }

      return filename;
    } catch (_) {
      return fallback;
    }
  }

  /// Formats file size from bytes to human-readable string.
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Formats a DateTime to a display-friendly date string.
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
