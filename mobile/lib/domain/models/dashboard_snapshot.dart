class DashboardSnapshot {
  DashboardSnapshot({
    required this.fullName,
    required this.monthlyTargetHours,
    required this.trackedHours,
    required this.leaveHours,
    required this.balanceHours,
    required this.focusItems,
    required this.distributionChannel,
  });

  final String fullName;
  final int monthlyTargetHours;
  final int trackedHours;
  final int leaveHours;
  final int balanceHours;
  final List<String> focusItems;
  final String distributionChannel;
}
