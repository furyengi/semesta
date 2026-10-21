import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/app.dart';
import 'package:semesta/data/store.dart';
import 'package:semesta/widgets/folder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.load();
  await tester.pumpWidget(
    SemestaApp(store: store, systemAccent: Future.value(null)),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('home shows headline, paste bar and collections', (tester) async {
    await _pump(tester);
    expect(find.text('Save now.\nFind anytime.'), findsOneWidget);
    expect(find.text('Paste link to save'), findsOneWidget);
    expect(find.text('My Collections'), findsOneWidget);
    expect(find.text('Unsorted'), findsOneWidget);
    expect(find.text('Must watch'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget); // Weekend Recipes
  });

  testWidgets('pasting a link saves it and offers to move it', (tester) async {
    final store = await _pump(tester);
    final before = store.linkCount('unsorted');

    await tester.enterText(find.byType(TextField), 'example.com/hello-world');
    await tester.tap(find.byTooltip('Save link'));
    await tester.pumpAndSettle();

    expect(store.linkCount('unsorted'), before + 1);
    expect(find.text('Saved to Unsorted'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(find.text('Move to'), findsOneWidget);
  });

  testWidgets('invalid input shows an inline error', (tester) async {
    final store = await _pump(tester);
    final before = store.linkCount('unsorted');
    await tester.enterText(find.byType(TextField), 'not a link');
    await tester.tap(find.byTooltip('Save link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('valid web link'), findsOneWidget);
    expect(store.linkCount('unsorted'), before);
  });

  testWidgets('opening a collection shows its links and sub-folders', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Learning & Research'));
    await tester.pumpAndSettle();
    expect(find.text('2 Folders'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Development'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('My Collections'), findsOneWidget);
  });

  testWidgets('search finds links and collections', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pancake');
    await tester.pumpAndSettle();
    expect(find.textContaining('Best pancake recipe'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Coffee & Chill Spots'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzzqq');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('settings switches theme mode', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('creating a collection adds a folder card', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Reading list');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderCard), findsWidgets);
    expect(find.text('Reading list'), findsOneWidget);
  });
}
