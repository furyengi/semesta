import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import '../screens/course_screen.dart';
import '../theme/app_theme.dart';
import '../theme/brutal_theme.dart';
import '../theme/motion.dart';
import 'brutal.dart';
import 'format.dart';

/// Folder-style card for a course. Opens its space with an M3 container
/// transform.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});

  final Course course;

  static const double tabInset = 14;

  /// Row height for grids of course cards, scaled for large text settings.
  static double extentFor(BuildContext context) =>
      186 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final brutal = BrutalTheme.of(context);
    final text = Theme.of(context).textTheme;
    final materials = store.docsForCourse(course.id).length;
    final open = store.openAssignmentCount(course.id);
    final next = store
        .upcoming(DateTime.now(), count: 1, courseId: course.id)
        .firstOrNull;
    final muted = text.labelMedium?.copyWith(color: scheme.onSurfaceVariant);

    final label = [
      course.name,
      '$materials materials',
      if (open > 0) '$open open assignments',
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BrutalShadow(
        topInset: tabInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: FractionallySizedBox(
                    widthFactor: .5,
                    child: Container(
                      height: tabInset + 14,
                      decoration: BoxDecoration(
                        color: course.color,
                        border: Border.all(
                          color: brutal.border,
                          width: brutal.borderWidth,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: tabInset),
              child: OpenContainer(
                transitionType: ContainerTransitionType.fadeThrough,
                transitionDuration: Motion.of(context, Motion.long2),
                closedElevation: 0,
                openElevation: 0,
                closedColor: brutal.card,
                openColor: scheme.surface,
                middleColor: scheme.surface,
                closedShape: brutalShape(context),
                openShape: const RoundedRectangleBorder(),
                routeSettings: RouteSettings(name: 'course/${course.id}'),
                openBuilder: (_, _) => CourseScreen(courseId: course.id),
                closedBuilder: (context, _) => Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: course.color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: brutal.border,
                                width: brutal.borderWidth,
                              ),
                            ),
                            child: Icon(
                              course.icon,
                              size: 22,
                              color: AccentPalette.on(course.color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (course.code.isNotEmpty)
                                  Text(
                                    course.code,
                                    style: text.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(plural(materials, 'file'), style: muted),
                                if (open > 0)
                                  Text(
                                    '$open due',
                                    style: muted?.copyWith(
                                      color: scheme.tertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        course.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next == null
                            ? 'No classes scheduled'
                            : '${relativeDay(next.start)} ${formatTime(context, next.start)}',
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';
