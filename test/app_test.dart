import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/models.dart';

import 'support/fakes.dart';

Future<void> _twoDocs(TestEnv e) async {
  await e.addDoc('linear_algebra.pdf');
  await e.addDoc('solo_leveling.pdf');
  final novel = e.store.docs.last;
  e.store.updateDoc(novel.id, category: DocCategory.manhwa);
}

Future<void> _openReader(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty library invites you to add a PDF', (tester) async {
    await pumpApp(tester);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Read. Learn.\nProgress.'), findsOneWidget);
    expect(find.text('Add PDF'), findsOneWidget);
    expect(find.text('Continue reading'.toUpperCase()), findsNothing);
  });

  testWidgets('home lists documents and filters by category', (tester) async {
    await pumpApp(tester, setup: _twoDocs);
    expect(find.text('Linear algebra'), findsOneWidget);
    expect(find.text('Solo leveling'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Manhwa'));
    await tester.pumpAndSettle();
    expect(find.text('Solo leveling'), findsOneWidget);
    expect(find.text('Linear algebra'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Linear algebra'), findsOneWidget);
  });

  testWidgets('opening a document starts on page 1 and saves progress', (
    tester,
  ) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    await _openReader(tester, 'Linear algebra');
    expect(find.text('viewer page 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-page')));
    await tester.tap(find.byKey(const Key('next-page')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final doc = env.store.docs.firstWhere((d) => d.title == 'Linear algebra');
    expect(doc.lastPage, 3);
    expect(doc.pageCount, 12);
    expect(find.text('Page 3 of 12'), findsOneWidget);
  });

  testWidgets(
    'reopening resumes where you left off and shows Continue reading',
    (tester) async {
      final env = await pumpApp(tester, setup: _twoDocs);
      final doc = env.store.docs.first;
      env.store.recordProgress(doc.id, page: 5, pageCount: 12);
      await tester.pumpAndSettle();

      expect(find.text('Pick up where\nyou left off.'), findsOneWidget);
      expect(find.text('Page 5 of 12'), findsOneWidget);

      await tester.tap(find.text('CONTINUE READING'));
      await tester.pumpAndSettle();
      expect(find.text('viewer page 5'), findsOneWidget);
    },
  );

  testWidgets('leaving the reader flushes the latest page', (tester) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    await _openReader(tester, 'Linear algebra');
    await tester.tap(find.byKey(const Key('next-page')));
    await tester.pump(); // before the debounce fires
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      env.store.docs.firstWhere((d) => d.title == 'Linear algebra').lastPage,
      2,
    );
  });

  testWidgets('bookmark toggles for the current page', (tester) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    await _openReader(tester, 'Linear algebra');
    final id = env.store.docs.firstWhere((d) => d.title == 'Linear algebra').id;

    await tester.tap(find.byTooltip('Bookmark this page'));
    await tester.pumpAndSettle();
    expect(env.store.doc(id)!.bookmarks.single.page, 1);
    expect(find.text('Bookmarked page 1'), findsOneWidget);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove bookmark'));
    await tester.pumpAndSettle();
    expect(env.store.doc(id)!.bookmarks, isEmpty);
  });

  testWidgets('bookmarks sheet jumps to a saved page', (tester) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    final id = env.store.docs.firstWhere((d) => d.title == 'Linear algebra').id;
    env.store.toggleBookmark(id, 9);
    await _openReader(tester, 'Linear algebra');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Page 9'));
    await tester.pumpAndSettle();
    expect(find.text('viewer page 9'), findsOneWidget);
  });

  testWidgets('go to page jumps and the slider shows progress', (tester) async {
    await pumpApp(tester, setup: _twoDocs);
    await _openReader(tester, 'Linear algebra');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to page'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('viewer page 12'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('tapping the page hides and shows the controls', (tester) async {
    await pumpApp(tester, setup: _twoDocs);
    await _openReader(tester, 'Linear algebra');
    final slider = find.byType(Slider);
    expect(tester.getTopLeft(slider).dy, lessThan(2400 / 3));

    await tester.tap(find.byKey(const Key('tap-page')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(slider).dy,
      greaterThan(2400 / 3),
    ); // slid off-screen

    await tester.tap(find.byKey(const Key('tap-page')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(slider).dy, lessThan(2400 / 3));
  });

  testWidgets('night reading toggles from the reader menu', (tester) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    await _openReader(tester, 'Linear algebra');
    expect(env.store.nightReading, isFalse);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night reading'));
    await tester.pumpAndSettle();
    expect(env.store.nightReading, isTrue);
  });

  testWidgets('a missing file offers to remove the entry', (tester) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    final doc = env.store.docs.firstWhere((d) => d.title == 'Linear algebra');
    await env.storage.delete(doc.storageKey);
    await _openReader(tester, 'Linear algebra');
    expect(find.text('This file isn’t available'), findsOneWidget);
    await tester.tap(find.text('Remove from library'));
    await tester.pumpAndSettle();
    expect(env.store.doc(doc.id), isNull);
  });

  testWidgets('long-press edits details and can remove a document', (
    tester,
  ) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    await tester.longPress(find.text('Linear algebra'));
    await tester.pumpAndSettle();
    expect(find.text('Document details'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Linear Algebra II');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Textbooks'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final doc = env.store.docs.firstWhere(
      (d) => d.title == 'Linear Algebra II',
    );
    expect(doc.category, DocCategory.textbook);

    await tester.longPress(find.text('Linear Algebra II'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(env.store.doc(doc.id), isNull);
    expect(env.storage.count, 1);
  });

  testWidgets('search finds documents by title and category', (tester) async {
    await pumpApp(tester, setup: _twoDocs);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'algebra');
    await tester.pumpAndSettle();
    expect(find.text('Linear algebra'), findsOneWidget);
    expect(find.text('Solo leveling'), findsNothing);

    await tester.enterText(find.byType(TextField), 'manhwa');
    await tester.pumpAndSettle();
    expect(find.text('Solo leveling'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('settings switches theme and night reading', (tester) async {
    final env = await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(env.store.themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.light,
    );
    await tester.tap(find.text('Night reading'));
    await tester.pumpAndSettle();
    expect(env.store.nightReading, isTrue);
  });

  testWidgets('deleting the library from settings', (tester) async {
    final env = await pumpApp(tester, setup: _twoDocs);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete the whole library'), 100);
    await tester.tap(find.text('Delete the whole library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    expect(env.store.docs, isEmpty);
    expect(env.storage.count, 0);
  });
}
