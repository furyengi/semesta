# Semesta

**Read. Organize. Understand. Progress.**

Semesta is a mobile reading and academic productivity app: one place for your
PDFs, course materials, timetable and study plan, built so that your reading
connects to your courses and your schedule.

Reading comes first. The calendar and planner exist to support it.

## Status

| Area | State |
| --- | --- |
| Library and PDF reader | **Done (this release)** |
| Course Spaces | Planned |
| Calendar and timetable | Planned |
| Study planner | Planned |
| Home-screen widgets | Planned (needs native Android code) |

### Library and reader

- Add PDFs from the device; they're copied into the app's private storage.
- Library grid with first-page covers, category filters and search.
- **Continue reading** card that resumes at the exact page.
- Reader: smooth scroll and zoom, tap to show or hide controls, page slider,
  go to page, bookmarks, and **night reading** (inverted colours that keep hues).
- Progress, last page and bookmarks are saved automatically.
- A short getting-started PDF is added on first launch.

## Design

Dark-first Material 3. The reader, search and settings stay calm and plain;
the bold outlined style from the original mock (thick borders, hard shadows)
is used only on the home screen and, later, course cards.

- Motion tokens live in `lib/theme/motion.dart`.
- Cards and the search button open with the M3 container transform; other
  pages use shared-axis; search results use fade-through.
- Animations are skipped when the system "reduce motion" setting is on.

## Code layout

```
lib/
  core/       PDF-engine and storage interfaces, import/seed/delete service
  platform/   pdfrx engine and on-device file storage
  data/       models and the persisted library store
  screens/    home, reader, search, settings
  widgets/    cards, covers, sheets, bold-style primitives
  theme/      Material 3 theme, motion, bold-style tokens
```

Screens depend on `PdfBackend` and `DocStorage` (injected through
`ServicesScope`), so tests run against fakes and the PDF engine can be swapped.

## Run

```sh
flutter pub get
flutter run            # Android device/emulator
flutter run -d chrome  # quick preview; files are kept in memory only
flutter test
```

Native builds use [pdfrx](https://pub.dev/packages/pdfrx) (PDFium) and need a C
toolchain; see its README for the native build requirements.

The Inter font (SIL OFL 1.1) is bundled in `assets/fonts/`.
