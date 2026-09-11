// Formattazione leggibile della dimensione di un download.

String formatDownloadSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
