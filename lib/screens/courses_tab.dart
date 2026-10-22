import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../widgets/brutal.dart';
import '../widgets/course_card.dart';
import '../widgets/schedule_tiles.dart';
import 'home_screen.dart' show contentGutter, gridColumns;

/// The Courses tab: deadlines across courses, then a card per course.
class CoursesTab extends StatelessWidget {
  const CoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);
    final courses = store.courses;
    final deadlines = store.openAssignmentsFrom(
      DateTime.now().subtract(const Duration(days: 365)),
      count: 3,
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
            sliver: SliverList.list(
              children: [
                Text('Your\ncourses.', style: text.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Every course has its materials. Every deadline has a plan.',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (deadlines.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Next deadlines', style: text.titleLarge),
                  const SizedBox(height: 12),
                  for (final a in deadlines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AssignmentTile(assignment: a, showCourse: true),
                    ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text('Courses', style: text.titleLarge),
                    const SizedBox(width: 8),
                    Text(
                      '${courses.length}',
                      style: text.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (courses.isEmpty)
            SliverToBoxAdapter(child: _EmptyCourses(gutter: gutter))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 112),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(context),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 18,
                  mainAxisExtent: CourseCard.extentFor(context),
                ),
                itemCount: courses.length,
                findChildIndexCallback: (key) {
                  final id = (key as ValueKey<String>).value;
                  final i = courses.indexWhere((c) => c.id == id);
                  return i < 0 ? null : i;
                },
                itemBuilder: (context, i) => Reveal(
                  key: ValueKey(courses[i].id),
                  index: i,
                  child: CourseCard(course: courses[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 120),
      child: Reveal(
        child: Column(
          children: [
            Icon(
              Icons.school_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No courses yet', style: text.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Add a course to gather its materials, classes and deadlines in one place.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
