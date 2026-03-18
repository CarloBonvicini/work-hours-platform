import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/dashboard_service.dart';
import 'package:work_hours_mobile/domain/models/dashboard_snapshot.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.dashboardService});

  final DashboardService dashboardService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DashboardSnapshot>(
          future: dashboardService.loadSnapshot(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Work Hours Platform',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bootstrap mobile pronto, distribuzione iniziale via ${data.distributionChannel}.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _HeroCard(snapshot: data),
                const SizedBox(height: 20),
                _MetricsGrid(snapshot: data),
                const SizedBox(height: 20),
                _FocusCard(items: data.focusItems),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const surfaceColor = Color(0xFF123131);
    const accentColor = Color(0xFFE6B84C);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ciao ${snapshot.fullName}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Primo obiettivo: pubblicare un APK scaricabile da GitHub.',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Canale di rilascio: ${snapshot.distributionChannel}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: surfaceColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _MetricCard(
          label: 'Target mensile',
          value: '${snapshot.monthlyTargetHours}h',
        ),
        _MetricCard(label: 'Ore tracciate', value: '${snapshot.trackedHours}h'),
        _MetricCard(label: 'Permessi/Ferie', value: '${snapshot.leaveHours}h'),
        _MetricCard(
          label: 'Saldo attuale',
          value: '${snapshot.balanceHours}h',
          emphasize: true,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: emphasize ? const Color(0xFFE6F0EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0D8CA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D8CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus immediato',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8, color: Color(0xFF0B6E69)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item, style: theme.textTheme.bodyLarge)),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
