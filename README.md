# Semesta

Save now. Find anytime. A Flutter app for saving links into colourful collections,
built on Material 3 with a bold outlined look (thick borders, hard offset shadows,
folder-tab cards).

## Features

- Paste a link and save it to **Unsorted** in one tap, then move it to a collection.
- Collections with colours and icons, plus nested folders.
- Search across links and collections.
- Swipe to delete with undo; rename, copy, move and open from the overflow menu.
- Light, dark and system themes, with optional Android dynamic colour.
- Everything is stored on-device (`shared_preferences`).

## Material 3 and motion

- `useMaterial3` with a full `ColorScheme`, M3 type scale, and M3 shapes for
  buttons, inputs, sheets, dialogs, snackbars, menus and segmented buttons
  (`lib/theme/app_theme.dart`).
- Motion tokens (durations and easing) live in `lib/theme/motion.dart`.
- Collection cards and the search button use the M3 **container transform**
  (`animations` package); other pages use the **shared axis** transition;
  search results cross-fade with **fade through**.
- Staggered entrance of cards, animated link counts, a rotating add/check button,
  a shake on invalid input, and press-into-shadow feedback.
- Animations are skipped when the system "reduce motion" setting is on.

## Run

```sh
flutter pub get
flutter run            # Android device/emulator, or: flutter run -d chrome
flutter test
```

The Inter font (SIL OFL 1.1) is bundled in `assets/fonts/`.
