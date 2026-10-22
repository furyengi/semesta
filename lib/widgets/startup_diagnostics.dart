import 'package:flutter/material.dart';

import '../startup_log.dart';

/// Shows problems recorded while the app started (the PDF engine, reminders
/// or widgets failing). Renders nothing when everything went fine.
class StartupDiagnostics extends StatelessWidget {
  const StartupDiagnostics({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StartupLog.instance,
      builder: (context, _) {
        final problems = StartupLog.instance.problems;
        if (problems.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(
                  Icons.bug_report_outlined,
                  color: scheme.onErrorContainer,
                ),
                title: Text(
                  'Something didn’t start (${problems.length})',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                subtitle: Text(
                  'Tap for details you can send to get it fixed',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    problems.join('\n\n'),
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
