// Blocco orario trascinabile/ridimensionabile dell'agenda e modalita di visualizzazione della superficie.

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/time_input_parser.dart';
import 'package:work_hours_mobile/domain/models/day_schedule.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/models/agenda_range.dart';
import 'package:work_hours_mobile/presentation/home/models/day_metrics.dart';
import 'package:work_hours_mobile/presentation/home/widgets/agenda/agenda_block_overlays.dart';

enum AgendaSurfaceDisplayMode { day, week }

class AgendaScheduleBlock extends StatefulWidget {
  const AgendaScheduleBlock({
    super.key,
    required this.metrics,
    required this.schedule,
    required this.startMinutes,
    required this.endMinutes,
    required this.range,
    required this.height,
    required this.displayMode,
    this.measurementSegments = const [],
    this.isProvisional = false,
    this.onPreviewChanged,
    this.onPreviewCleared,
    this.onScheduleChanged,
    this.onInteractionChanged,
  });

  final DayMetrics metrics;
  final DaySchedule schedule;
  final int startMinutes;
  final int endMinutes;
  final AgendaRange range;
  final double height;
  final AgendaSurfaceDisplayMode displayMode;
  final List<AgendaMeasurementSegment> measurementSegments;
  final bool isProvisional;
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
  State<AgendaScheduleBlock> createState() => AgendaScheduleBlockState();
}

enum AgendaDragMode {
  move,
  resizeStart,
  resizeEnd,
  movePause,
  resizePauseStart,
  resizePauseEnd,
}

class AgendaScheduleBlockState extends State<AgendaScheduleBlock> {
  AgendaDragMode? _dragMode;
  double _dragOffset = 0;
  double _dragMinutesPerPixel = 1;
  late int _dragStartMinutes;
  late int _dragEndMinutes;
  int? _dragPauseStartMinutes;
  int? _dragPauseEndMinutes;
  int? _previewStartMinutes;
  int? _previewEndMinutes;
  int? _previewBreakMinutes;
  int? _previewPauseStartMinutes;
  int? _previewPauseEndMinutes;

  @override
  void dispose() {
    widget.onInteractionChanged?.call(false);
    super.dispose();
  }

  int get _displayStartMinutes => _previewStartMinutes ?? widget.startMinutes;

  int get _displayEndMinutes => _previewEndMinutes ?? widget.endMinutes;

  AgendaMeasurementSegment? _resolveFirstPauseSegment(
    List<AgendaMeasurementSegment> segments,
  ) {
    for (final segment in segments) {
      if (segment.kind == AgendaMeasurementSegmentKind.pause) {
        return segment;
      }
    }
    return null;
  }

  List<AgendaMeasurementSegment> _buildSegmentsFromPauseWindow({
    required int startMinutes,
    required int endMinutes,
    int? pauseStartMinutes,
    int? pauseEndMinutes,
    required List<AgendaMeasurementSegment> fallbackSegments,
  }) {
    if (pauseStartMinutes == null ||
        pauseEndMinutes == null ||
        pauseEndMinutes <= pauseStartMinutes) {
      return fallbackSegments;
    }

    final segments = <AgendaMeasurementSegment>[];
    if (pauseStartMinutes > startMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: startMinutes,
          endMinutes: pauseStartMinutes,
          label: '',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    segments.add(
      AgendaMeasurementSegment(
        startMinutes: pauseStartMinutes,
        endMinutes: pauseEndMinutes,
        label: '',
        kind: AgendaMeasurementSegmentKind.pause,
      ),
    );
    if (pauseEndMinutes < endMinutes) {
      segments.add(
        AgendaMeasurementSegment(
          startMinutes: pauseEndMinutes,
          endMinutes: endMinutes,
          label: '',
          kind: AgendaMeasurementSegmentKind.work,
        ),
      );
    }
    return segments;
  }

  List<AgendaMeasurementSegment> _displaySegments({
    required int startMinutes,
    required int endMinutes,
  }) {
    final fallbackSegments = resolveEffectiveAgendaSegments(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      measurementSegments: widget.measurementSegments,
    );
    return _buildSegmentsFromPauseWindow(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      pauseStartMinutes: _previewPauseStartMinutes,
      pauseEndMinutes: _previewPauseEndMinutes,
      fallbackSegments: fallbackSegments,
    );
  }

  void _emitPreviewChanged() {
    final committedStartMinutes = _previewStartMinutes ?? widget.startMinutes;
    final committedEndMinutes = _previewEndMinutes ?? widget.endMinutes;
    final committedBreakMinutes =
        (_previewPauseStartMinutes != null && _previewPauseEndMinutes != null)
        ? _previewPauseEndMinutes! - _previewPauseStartMinutes!
        : (_previewBreakMinutes ?? widget.schedule.breakMinutes);
    widget.onPreviewChanged?.call(
      startMinutes: committedStartMinutes,
      endMinutes: committedEndMinutes,
      breakMinutes: committedBreakMinutes,
      pauseStartMinutes: _previewPauseStartMinutes,
      pauseEndMinutes: _previewPauseEndMinutes,
    );
  }

  int _clampAgendaMinute(int minutes) {
    return minutes.clamp(0, (23 * 60) + 59).toInt();
  }

  void _handleDragStart(AgendaDragMode mode) {
    final initialSegments = _displaySegments(
      startMinutes: _displayStartMinutes,
      endMinutes: _displayEndMinutes,
    );
    final pauseSegment = _resolveFirstPauseSegment(initialSegments);
    setState(() {
      _dragMode = mode;
      _dragOffset = 0;
      _dragMinutesPerPixel = widget.height <= 0
          ? 1
          : widget.range.totalMinutes / widget.height;
      _dragStartMinutes = _displayStartMinutes;
      _dragEndMinutes = _displayEndMinutes;
      _dragPauseStartMinutes = pauseSegment?.startMinutes;
      _dragPauseEndMinutes = pauseSegment?.endMinutes;
      _previewStartMinutes = _displayStartMinutes;
      _previewEndMinutes = _displayEndMinutes;
      _previewBreakMinutes = widget.schedule.breakMinutes;
      _previewPauseStartMinutes = pauseSegment?.startMinutes;
      _previewPauseEndMinutes = pauseSegment?.endMinutes;
    });
    widget.onInteractionChanged?.call(true);
    assert(() {
      debugPrint(
        '[agenda-drag-start] mode=$mode start=${formatTimeInput(_dragStartMinutes)} end=${formatTimeInput(_dragEndMinutes)} '
        'pauseStart=${_dragPauseStartMinutes == null ? '-' : formatTimeInput(_dragPauseStartMinutes!)} '
        'pauseEnd=${_dragPauseEndMinutes == null ? '-' : formatTimeInput(_dragPauseEndMinutes!)} '
        'minutesPerPixel=${_dragMinutesPerPixel.toStringAsFixed(4)}',
      );
      return true;
    }());
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragMode == null || widget.onScheduleChanged == null) {
      return;
    }

    _dragOffset += details.primaryDelta ?? 0;
    final durationMinutes = _dragEndMinutes - _dragStartMinutes;
    final deltaMinutes = (_dragOffset * _dragMinutesPerPixel).round();

    void applyPreview({
      required int startMinutes,
      required int endMinutes,
      int? pauseStartMinutes,
      int? pauseEndMinutes,
    }) {
      setState(() {
        _previewStartMinutes = startMinutes;
        _previewEndMinutes = endMinutes;
        _previewPauseStartMinutes = pauseStartMinutes;
        _previewPauseEndMinutes = pauseEndMinutes;
        _previewBreakMinutes =
            pauseStartMinutes != null && pauseEndMinutes != null
            ? pauseEndMinutes - pauseStartMinutes
            : math.min(widget.schedule.breakMinutes, endMinutes - startMinutes);
      });
      _emitPreviewChanged();
    }

    switch (_dragMode!) {
      case AgendaDragMode.move:
        final maxStart = math.max(0, ((23 * 60) + 59) - durationMinutes);
        final clampedStart = _clampAgendaMinute(
          _dragStartMinutes + deltaMinutes,
        ).clamp(0, maxStart).toInt();
        final actualDeltaMinutes = clampedStart - _dragStartMinutes;
        final shiftedPauseStart = _dragPauseStartMinutes == null
            ? null
            : _dragPauseStartMinutes! + actualDeltaMinutes;
        final shiftedPauseEnd = _dragPauseEndMinutes == null
            ? null
            : _dragPauseEndMinutes! + actualDeltaMinutes;
        applyPreview(
          startMinutes: clampedStart,
          endMinutes: clampedStart + durationMinutes,
          pauseStartMinutes: shiftedPauseStart,
          pauseEndMinutes: shiftedPauseEnd,
        );
        return;
      case AgendaDragMode.resizeStart:
        final clampedStart = _clampAgendaMinute(
          _dragStartMinutes + deltaMinutes,
        ).clamp(0, _dragEndMinutes - 1).toInt();
        final nextPauseStart = _dragPauseStartMinutes == null
            ? null
            : math.max(_dragPauseStartMinutes!, clampedStart);
        final nextPauseEnd = _dragPauseEndMinutes == null
            ? null
            : math.max(
                _dragPauseEndMinutes!,
                (nextPauseStart ?? clampedStart) + 1,
              );
        applyPreview(
          startMinutes: clampedStart,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: nextPauseStart,
          pauseEndMinutes: nextPauseEnd == null
              ? null
              : math.min(nextPauseEnd, _dragEndMinutes),
        );
        return;
      case AgendaDragMode.resizeEnd:
        final clampedEnd = _clampAgendaMinute(
          _dragEndMinutes + deltaMinutes,
        ).clamp(_dragStartMinutes + 1, (23 * 60) + 59).toInt();
        final nextPauseStart = _dragPauseStartMinutes;
        final nextPauseEnd = _dragPauseEndMinutes == null
            ? null
            : math.min(_dragPauseEndMinutes!, clampedEnd);
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: clampedEnd,
          pauseStartMinutes: nextPauseStart,
          pauseEndMinutes: nextPauseEnd,
        );
        return;
      case AgendaDragMode.movePause:
        if (_dragPauseStartMinutes == null || _dragPauseEndMinutes == null) {
          return;
        }
        final pauseDurationMinutes =
            _dragPauseEndMinutes! - _dragPauseStartMinutes!;
        final clampedPauseStart = (_dragPauseStartMinutes! + deltaMinutes)
            .clamp(_dragStartMinutes, _dragEndMinutes - pauseDurationMinutes)
            .toInt();
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: clampedPauseStart,
          pauseEndMinutes: clampedPauseStart + pauseDurationMinutes,
        );
        return;
      case AgendaDragMode.resizePauseStart:
        if (_dragPauseStartMinutes == null || _dragPauseEndMinutes == null) {
          return;
        }
        final clampedPauseStart = (_dragPauseStartMinutes! + deltaMinutes)
            .clamp(_dragStartMinutes, _dragPauseEndMinutes! - 1)
            .toInt();
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: clampedPauseStart,
          pauseEndMinutes: _dragPauseEndMinutes,
        );
        return;
      case AgendaDragMode.resizePauseEnd:
        if (_dragPauseStartMinutes == null || _dragPauseEndMinutes == null) {
          return;
        }
        final clampedPauseEnd = (_dragPauseEndMinutes! + deltaMinutes)
            .clamp(_dragPauseStartMinutes! + 1, _dragEndMinutes)
            .toInt();
        applyPreview(
          startMinutes: _dragStartMinutes,
          endMinutes: _dragEndMinutes,
          pauseStartMinutes: _dragPauseStartMinutes,
          pauseEndMinutes: clampedPauseEnd,
        );
        return;
    }
  }

  void _handleDragEnd([DragEndDetails? _]) {
    final committedStartMinutes = _previewStartMinutes ?? widget.startMinutes;
    final committedEndMinutes = _previewEndMinutes ?? widget.endMinutes;
    final committedBreakMinutes =
        (_previewPauseStartMinutes != null && _previewPauseEndMinutes != null)
        ? _previewPauseEndMinutes! - _previewPauseStartMinutes!
        : (_previewBreakMinutes ?? widget.schedule.breakMinutes);
    final committedPauseStartMinutes = _previewPauseStartMinutes;
    final committedPauseEndMinutes = _previewPauseEndMinutes;
    final initialBreakMinutes =
        (_dragPauseStartMinutes != null && _dragPauseEndMinutes != null)
        ? _dragPauseEndMinutes! - _dragPauseStartMinutes!
        : widget.schedule.breakMinutes;
    final hasChanged =
        committedStartMinutes != _dragStartMinutes ||
        committedEndMinutes != _dragEndMinutes ||
        committedBreakMinutes != initialBreakMinutes ||
        committedPauseStartMinutes != _dragPauseStartMinutes ||
        committedPauseEndMinutes != _dragPauseEndMinutes;

    assert(() {
      debugPrint(
        '[agenda-drag-end] mode=$_dragMode changed=$hasChanged '
        'initialStart=${formatTimeInput(_dragStartMinutes)} initialEnd=${formatTimeInput(_dragEndMinutes)} '
        'start=${formatTimeInput(committedStartMinutes)} end=${formatTimeInput(committedEndMinutes)} '
        'break=$committedBreakMinutes '
        'pauseStart=${committedPauseStartMinutes == null ? '-' : formatTimeInput(committedPauseStartMinutes)} '
        'pauseEnd=${committedPauseEndMinutes == null ? '-' : formatTimeInput(committedPauseEndMinutes)}',
      );
      return true;
    }());

    if (!hasChanged || widget.onScheduleChanged == null) {
      setState(() {
        _dragMode = null;
        _dragOffset = 0;
        _previewStartMinutes = null;
        _previewEndMinutes = null;
        _previewBreakMinutes = null;
        _previewPauseStartMinutes = null;
        _previewPauseEndMinutes = null;
      });
      widget.onInteractionChanged?.call(false);
      widget.onPreviewCleared?.call();
      return;
    }

    setState(() {
      _dragMode = null;
      _dragOffset = 0;
    });
    widget.onInteractionChanged?.call(false);

    widget.onScheduleChanged!(
      startMinutes: committedStartMinutes,
      endMinutes: committedEndMinutes,
      breakMinutes: committedBreakMinutes,
      pauseStartMinutes: committedPauseStartMinutes,
      pauseEndMinutes: committedPauseEndMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDayMode = widget.displayMode == AgendaSurfaceDisplayMode.day;
    final backgroundColor = widget.metrics.hasOverride
        ? Color.lerp(colorScheme.surface, colorScheme.secondary, 0.28)!
        : Color.lerp(colorScheme.surface, colorScheme.primary, 0.22)!;
    final surfaceFillColor = isDayMode ? Colors.transparent : backgroundColor;
    final segmentCanvasColor = isDayMode
        ? colorScheme.surfaceContainerHigh.withValues(
            alpha: isDark ? 0.72 : 0.94,
          )
        : surfaceFillColor;
    final borderColor = widget.metrics.hasOverride
        ? colorScheme.secondary
        : colorScheme.primary;
    final displayStartMinutes = _previewStartMinutes ?? widget.startMinutes;
    final displayEndMinutes = _previewEndMinutes ?? widget.endMinutes;
    final effectiveSegments = _displaySegments(
      startMinutes: displayStartMinutes,
      endMinutes: displayEndMinutes,
    );
    final pauseSegment = _resolveFirstPauseSegment(effectiveSegments);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showHandles =
            widget.displayMode == AgendaSurfaceDisplayMode.day &&
            widget.onScheduleChanged != null &&
            constraints.maxHeight >= 72;
        final textColor = widget.metrics.hasOverride
            ? colorScheme.onSecondaryContainer
            : colorScheme.onPrimaryContainer;
        final verticalInset = isDayMode ? 0.0 : 6.0;
        final drawableHeight = math.max(
          1.0,
          constraints.maxHeight - (verticalInset * 2),
        );
        final blockDurationMinutes = math.max(
          1,
          displayEndMinutes - displayStartMinutes,
        );
        double localTopForMinute(int minute) {
          final clampedMinute = minute.clamp(
            displayStartMinutes,
            displayEndMinutes,
          );
          final normalizedMinute =
              (clampedMinute - displayStartMinutes) / blockDurationMinutes;
          return verticalInset + (normalizedMinute * drawableHeight);
        }

        final content = Container(
          padding: EdgeInsets.fromLTRB(10, verticalInset, 10, verticalInset),
          decoration: BoxDecoration(
            color: surfaceFillColor,
            borderRadius: BorderRadius.circular(18),
            border: isDayMode
                ? null
                : Border.all(color: borderColor, width: 1.2),
            boxShadow: isDayMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.08,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (widget.isProvisional)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        painter: AgendaTentativeOverlayPainter(
                          color: textColor.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
                ),
              DefaultTextStyle(
                style:
                    theme.textTheme.bodySmall?.copyWith(color: textColor) ??
                    TextStyle(color: textColor),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, bodyConstraints) {
                          final interactiveHeight = bodyConstraints.maxHeight;
                          return GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart:
                                widget.onScheduleChanged == null
                                ? null
                                : (_) => _handleDragStart(AgendaDragMode.move),
                            onVerticalDragUpdate:
                                widget.onScheduleChanged == null
                                ? null
                                : _handleDragUpdate,
                            onVerticalDragEnd: widget.onScheduleChanged == null
                                ? null
                                : _handleDragEnd,
                            child: Stack(
                              children: [
                                if (widget.displayMode ==
                                        AgendaSurfaceDisplayMode.day ||
                                    widget.displayMode ==
                                        AgendaSurfaceDisplayMode.week)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: segmentCanvasColor,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: AgendaSegmentFillOverlay(
                                            startMinutes: displayStartMinutes,
                                            endMinutes: displayEndMinutes,
                                            segments: effectiveSegments,
                                            workColor: colorScheme.primary
                                                .withValues(
                                                  alpha:
                                                      widget.displayMode ==
                                                          AgendaSurfaceDisplayMode
                                                              .day
                                                      ? 0.3
                                                      : 0.26,
                                                ),
                                            pauseColor: colorScheme.secondary
                                                .withValues(
                                                  alpha:
                                                      widget.displayMode ==
                                                          AgendaSurfaceDisplayMode
                                                              .day
                                                      ? 0.68
                                                      : 0.62,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.displayMode ==
                                        AgendaSurfaceDisplayMode.day &&
                                    pauseSegment != null)
                                  AgendaPauseEditOverlay(
                                    range: widget.range,
                                    height: interactiveHeight,
                                    blockStartMinutes: displayStartMinutes,
                                    blockEndMinutes: displayEndMinutes,
                                    pauseSegment: pauseSegment,
                                    onMovePauseStart:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : () => _handleDragStart(
                                            AgendaDragMode.movePause,
                                          ),
                                    onResizePauseStart:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : () => _handleDragStart(
                                            AgendaDragMode.resizePauseStart,
                                          ),
                                    onResizePauseEnd:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : () => _handleDragStart(
                                            AgendaDragMode.resizePauseEnd,
                                          ),
                                    onDragUpdate:
                                        widget.onScheduleChanged == null
                                        ? null
                                        : _handleDragUpdate,
                                    onDragEnd: widget.onScheduleChanged == null
                                        ? null
                                        : _handleDragEnd,
                                    chipColor: colorScheme.secondary,
                                    surfaceColor: colorScheme.surface,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (showHandles)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) =>
                                _handleDragStart(AgendaDragMode.resizeStart),
                            onVerticalDragUpdate: _handleDragUpdate,
                            onVerticalDragEnd: _handleDragEnd,
                            child: AgendaResizeHandle(color: textColor),
                          ),
                        ),
                      ),
                    if (showHandles)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: GestureDetector(
                            dragStartBehavior: DragStartBehavior.down,
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) =>
                                _handleDragStart(AgendaDragMode.resizeEnd),
                            onVerticalDragUpdate: _handleDragUpdate,
                            onVerticalDragEnd: _handleDragEnd,
                            child: AgendaResizeHandle(color: textColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

        final decoratedContent =
            widget.displayMode == AgendaSurfaceDisplayMode.day ||
                widget.displayMode == AgendaSurfaceDisplayMode.week
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  content,
                  Positioned(
                    top: widget.displayMode == AgendaSurfaceDisplayMode.day
                        ? -12
                        : -10,
                    right: widget.displayMode == AgendaSurfaceDisplayMode.day
                        ? 12
                        : 8,
                    child: AgendaDragTimeChip(
                      label: formatTimeInput(displayStartMinutes),
                      compact:
                          widget.displayMode == AgendaSurfaceDisplayMode.week,
                    ),
                  ),
                  Positioned(
                    bottom: widget.displayMode == AgendaSurfaceDisplayMode.day
                        ? -12
                        : -10,
                    right: widget.displayMode == AgendaSurfaceDisplayMode.day
                        ? 12
                        : 8,
                    child: AgendaDragTimeChip(
                      label: formatTimeInput(displayEndMinutes),
                      compact:
                          widget.displayMode == AgendaSurfaceDisplayMode.week,
                    ),
                  ),
                  if (pauseSegment != null) ...[
                    Positioned(
                      top:
                          localTopForMinute(pauseSegment.startMinutes) -
                          (widget.displayMode == AgendaSurfaceDisplayMode.day
                              ? 12
                              : 10),
                      left: widget.displayMode == AgendaSurfaceDisplayMode.day
                          ? 12
                          : 8,
                      child: AgendaDragTimeChip(
                        label: formatTimeInput(pauseSegment.startMinutes),
                        accentColor: colorScheme.secondary,
                        compact:
                            widget.displayMode == AgendaSurfaceDisplayMode.week,
                      ),
                    ),
                    Positioned(
                      top:
                          localTopForMinute(pauseSegment.endMinutes) -
                          (widget.displayMode == AgendaSurfaceDisplayMode.day
                              ? 12
                              : 10),
                      left: widget.displayMode == AgendaSurfaceDisplayMode.day
                          ? 12
                          : 8,
                      child: AgendaDragTimeChip(
                        label: formatTimeInput(pauseSegment.endMinutes),
                        accentColor: colorScheme.secondary,
                        compact:
                            widget.displayMode == AgendaSurfaceDisplayMode.week,
                      ),
                    ),
                  ],
                ],
              )
            : content;

        if (widget.onScheduleChanged == null) {
          return decoratedContent;
        }

        return MouseRegion(
          cursor: SystemMouseCursors.move,
          child: decoratedContent,
        );
      },
    );
  }
}
