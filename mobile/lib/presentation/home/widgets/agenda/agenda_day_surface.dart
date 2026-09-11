// Superficie del giorno in agenda su cui si posizionano i blocchi orario.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/models/agenda_range.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/agenda/agenda_schedule_block.dart';

class AgendaDaySurface extends StatefulWidget {
  const AgendaDaySurface({
    super.key,
    required this.metrics,
    required this.schedule,
    required this.range,
    required this.height,
    this.displayMode = AgendaSurfaceDisplayMode.day,
    this.isSelected = false,
    this.isProvisional = false,
    this.measurementSegments = const [],
    this.onTap,
    this.onPreviewChanged,
    this.onPreviewCleared,
    this.onScheduleChanged,
    this.onInteractionChanged,
  });

  final DayMetrics metrics;
  final DaySchedule schedule;
  final AgendaRange range;
  final double height;
  final AgendaSurfaceDisplayMode displayMode;
  final bool isSelected;
  final bool isProvisional;
  final List<AgendaMeasurementSegment> measurementSegments;
  final VoidCallback? onTap;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })?
  onPreviewChanged;
  final VoidCallback? onPreviewCleared;
  final void Function({
    required int startMinutes,
    required int endMinutes,
    int? breakMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
  })?
  onScheduleChanged;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<AgendaDaySurface> createState() => AgendaDaySurfaceState();
}

class AgendaDaySurfaceState extends State<AgendaDaySurface> {
  int? _previewStartMinutes;
  int? _previewEndMinutes;
  int? _previewBreakMinutes;

  @override
  void didUpdateWidget(covariant AgendaDaySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scheduledStart = parseTimeInput(widget.schedule.startTime);
    final scheduledEnd = parseTimeInput(widget.schedule.endTime);
    final previewMatchesCommitted =
        _previewStartMinutes != null &&
        _previewEndMinutes != null &&
        scheduledStart == _previewStartMinutes &&
        scheduledEnd == _previewEndMinutes &&
        widget.schedule.breakMinutes ==
            (_previewBreakMinutes ?? widget.schedule.breakMinutes);

    if (previewMatchesCommitted ||
        oldWidget.schedule.startTime != widget.schedule.startTime ||
        oldWidget.schedule.endTime != widget.schedule.endTime ||
        oldWidget.schedule.breakMinutes != widget.schedule.breakMinutes) {
      _previewStartMinutes = null;
      _previewEndMinutes = null;
      _previewBreakMinutes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lineColor = colorScheme.outlineVariant.withValues(alpha: 0.45);
    final surfaceColor = widget.isSelected
        ? Color.lerp(colorScheme.surface, colorScheme.primary, 0.08)!
        : colorScheme.surface;
    final borderColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final scheduledStart =
        _previewStartMinutes ?? parseTimeInput(widget.schedule.startTime);
    final scheduledEnd =
        _previewEndMinutes ?? parseTimeInput(widget.schedule.endTime);
    final inferredSegments =
        scheduledStart != null &&
            scheduledEnd != null &&
            scheduledEnd > scheduledStart
        ? resolveEffectiveAgendaSegments(
            startMinutes: scheduledStart,
            endMinutes: scheduledEnd,
            measurementSegments: widget.measurementSegments,
          )
        : const <AgendaMeasurementSegment>[];
    final inferredStart = inferredSegments.isEmpty
        ? null
        : inferredSegments
              .map((segment) => segment.startMinutes)
              .reduce(math.min);
    final inferredEnd = inferredSegments.isEmpty
        ? null
        : inferredSegments
              .map((segment) => segment.endMinutes)
              .reduce(math.max);
    final resolvedStart = scheduledStart ?? inferredStart;
    final resolvedEnd = scheduledEnd ?? inferredEnd;
    final hasStructuredSchedule =
        resolvedStart != null &&
        resolvedEnd != null &&
        resolvedEnd > resolvedStart;
    const blockRightInset = 10.0;

    final content = Ink(
      height: widget.height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: widget.isSelected ? 1.4 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final mark in widget.range.hourMarks)
            Positioned(
              top: widget.range.positionFor(mark, widget.height),
              left: 0,
              right: 0,
              child: Container(height: 1, color: lineColor),
            ),
          if (hasStructuredSchedule)
            Positioned(
              top: widget.range.positionFor(resolvedStart, widget.height),
              left: 10,
              right: blockRightInset,
              height: math.max(
                widget.range.positionFor(resolvedEnd, widget.height) -
                    widget.range.positionFor(resolvedStart, widget.height),
                28,
              ),
              child: AgendaScheduleBlock(
                metrics: widget.metrics,
                schedule: widget.schedule,
                startMinutes: resolvedStart,
                endMinutes: resolvedEnd,
                range: widget.range,
                height: widget.height,
                displayMode: widget.displayMode,
                measurementSegments: widget.measurementSegments,
                isProvisional: widget.isProvisional,
                onPreviewChanged:
                    ({
                      required int startMinutes,
                      required int endMinutes,
                      int? breakMinutes,
                      int? pauseStartMinutes,
                      int? pauseEndMinutes,
                    }) {
                      setState(() {
                        _previewStartMinutes = startMinutes;
                        _previewEndMinutes = endMinutes;
                        _previewBreakMinutes = breakMinutes;
                      });
                      widget.onPreviewChanged?.call(
                        startMinutes: startMinutes,
                        endMinutes: endMinutes,
                        breakMinutes: breakMinutes,
                        pauseStartMinutes: pauseStartMinutes,
                        pauseEndMinutes: pauseEndMinutes,
                      );
                    },
                onPreviewCleared: () {
                  setState(() {
                    _previewStartMinutes = null;
                    _previewEndMinutes = null;
                    _previewBreakMinutes = null;
                  });
                  widget.onPreviewCleared?.call();
                },
                onScheduleChanged: widget.onScheduleChanged,
                onInteractionChanged: widget.onInteractionChanged,
              ),
            ),
          if (!hasStructuredSchedule &&
              widget.displayMode == AgendaSurfaceDisplayMode.day)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.schedule_outlined,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
