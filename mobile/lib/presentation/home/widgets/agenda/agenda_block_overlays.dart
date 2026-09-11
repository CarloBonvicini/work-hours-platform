// Maniglie, chip e overlay usati durante il trascinamento dei blocchi agenda.

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:work_hours_mobile/application/services/hour_input_parser.dart';
import 'package:work_hours_mobile/presentation/home/logic/agenda_segments.dart';
import 'package:work_hours_mobile/presentation/home/models/agenda_range.dart';

class AgendaResizeHandle extends StatelessWidget {
  const AgendaResizeHandle({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 18,
      alignment: Alignment.center,
      child: Container(
        width: 28,
        height: 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class AgendaDragTimeChip extends StatelessWidget {
  const AgendaDragTimeChip({
    super.key,
    required this.label,
    this.accentColor,
    this.compact = false,
  });

  final String label;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style:
            (compact ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
                ?.copyWith(color: borderColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class AgendaPauseEditOverlay extends StatelessWidget {
  const AgendaPauseEditOverlay({
    super.key,
    required this.range,
    required this.height,
    required this.blockStartMinutes,
    required this.blockEndMinutes,
    required this.pauseSegment,
    required this.chipColor,
    required this.surfaceColor,
    this.onMovePauseStart,
    this.onResizePauseStart,
    this.onResizePauseEnd,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final AgendaRange range;
  final double height;
  final int blockStartMinutes;
  final int blockEndMinutes;
  final AgendaMeasurementSegment pauseSegment;
  final Color chipColor;
  final Color surfaceColor;
  final VoidCallback? onMovePauseStart;
  final VoidCallback? onResizePauseStart;
  final VoidCallback? onResizePauseEnd;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = math.max(1, blockEndMinutes - blockStartMinutes);
    final pauseTop =
        ((pauseSegment.startMinutes - blockStartMinutes) / totalMinutes) *
        height;
    final pauseHeight = math
        .max(
          16,
          ((pauseSegment.endMinutes - pauseSegment.startMinutes) /
                  totalMinutes) *
              height,
        )
        .toDouble();

    return Positioned(
      top: pauseTop,
      left: 14,
      right: 14,
      height: pauseHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              dragStartBehavior: DragStartBehavior.down,
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: onMovePauseStart == null
                  ? null
                  : (_) => onMovePauseStart!(),
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: chipColor.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: onResizePauseStart == null
                    ? null
                    : (_) => onResizePauseStart!(),
                onVerticalDragUpdate: onDragUpdate,
                onVerticalDragEnd: onDragEnd,
                child: AgendaResizeHandle(color: surfaceColor),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: onResizePauseEnd == null
                    ? null
                    : (_) => onResizePauseEnd!(),
                onVerticalDragUpdate: onDragUpdate,
                onVerticalDragEnd: onDragEnd,
                child: AgendaResizeHandle(color: surfaceColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgendaSegmentFillOverlay extends StatelessWidget {
  const AgendaSegmentFillOverlay({
    super.key,
    required this.startMinutes,
    required this.endMinutes,
    required this.segments,
    required this.workColor,
    required this.pauseColor,
  });

  final int startMinutes;
  final int endMinutes;
  final List<AgendaMeasurementSegment> segments;
  final Color workColor;
  final Color pauseColor;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = math.max(1, endMinutes - startMinutes);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final segment in segments)
              () {
                final segmentHeight = math
                    .max(
                      10,
                      ((segment.endMinutes - segment.startMinutes) /
                              totalMinutes) *
                          constraints.maxHeight,
                    )
                    .toDouble();
                final segmentColor =
                    segment.kind == AgendaMeasurementSegmentKind.pause
                    ? pauseColor
                    : workColor;
                final segmentMinutes =
                    segment.endMinutes - segment.startMinutes;
                final showLabel =
                    segmentHeight >= 34 && constraints.maxWidth >= 72;
                return Positioned(
                  top:
                      ((segment.startMinutes - startMinutes) / totalMinutes) *
                      constraints.maxHeight,
                  left: 0,
                  right: 0,
                  height: segmentHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: segmentColor),
                    child: showLabel
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                formatHoursInput(segmentMinutes),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                            segmentColor,
                                          ) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

class AgendaTentativeOverlayPainter extends CustomPainter {
  const AgendaTentativeOverlayPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const spacing = 14.0;
    for (double startX = -size.height; startX < size.width; startX += spacing) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AgendaTentativeOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
