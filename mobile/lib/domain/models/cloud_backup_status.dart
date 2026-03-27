class CloudBackupStatus {
  const CloudBackupStatus({
    required this.hasBackup,
    this.updatedAt,
    this.droppedWorkEntries = 0,
    this.droppedLeaveEntries = 0,
    this.droppedScheduleOverrides = 0,
  });

  final bool hasBackup;
  final DateTime? updatedAt;
  final int droppedWorkEntries;
  final int droppedLeaveEntries;
  final int droppedScheduleOverrides;

  int get droppedItemsCount =>
      droppedWorkEntries + droppedLeaveEntries + droppedScheduleOverrides;
}
