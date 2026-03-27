class CloudBackupStatus {
  const CloudBackupStatus({
    required this.hasBackup,
    this.updatedAt,
  });

  final bool hasBackup;
  final DateTime? updatedAt;
}
