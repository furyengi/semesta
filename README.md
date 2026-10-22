# Semesta

**Read. Organize. Understand. Progress.**

Semesta is a mobile reading and academic productivity app: one place for your
PDFs, course materials, timetable and study plan, built so that your reading
connects to your courses and your schedule.

Reading comes first. The calendar and planner exist to support it.

## Status

| Area | State |
| --- | --- |
| Library and PDF reader | Done |
| Course Spaces | Done |
| Calendar and timetable | Done |
| Study planner | **Done (this release)** |
| Reminders and home-screen widgets | Planned (need native Android code) |

### Library and reader

- Add PDFs from the device; they're copied into the app's private storage.
- Library grid with first-page covers, category filters and search.
- **Continue reading** card that resumes at the exact page.
- Reader: smooth scroll and zoom, tap to show or hide controls, page slider,
  go to page, bookmarks, and **night reading** (inverted colours that keep hues).
- Progress, last page and bookmarks are saved automatically.

### Courses

- A space per course: schedule, materials, assignments and free-form notes.
- Attach library documents to a course (or pick the course in a document's
  details). Removing a course keeps the documents.
- Assignments with due dates, a tick-off checkbox and an optional linked page.

### Calendar

- **Day** (timeline with overlapping events side by side and a now line),
  **Week** (grouped by day) and **Month** (dots per day plus that day's agenda).
- One-off events and classes that repeat weekly (optionally until a date),
  for lectures, practicals, exams, study sessions and anything else.
- Deadlines from assignments show on their due day.
- **Events link to material**: a lecture can open the exact PDF page, from the
  calendar, the course space, or the *Next up* card on the Library tab.

### Study planner

- Make a plan for an exam, an assignment, or anything with a date: pick the
  date, how many hours, session length, which weekdays and a start time.
- Semesta spreads the sessions **evenly** over the days before the date and
  moves them off anything already scheduled (classes, exams, other plans).
- Optionally give it a reading range (a document and pages): each session gets
  its own share and links straight to its first page.
- The **Plan** tab shows this week's progress, what **needs attention**
  (missed sessions, exams and deadlines with no plan yet), today's sessions
  and every plan with an *on track / behind* status.
- Tick sessions off, move them to today or tomorrow, reschedule or delete
  them (with undo), add your own, or **re-plan what's left** after a missed
  day; finished sessions and the pages already covered are kept.
- Sessions also appear in the Day, Week and Month calendar views and in the
  Library's *Next up* card.

## Design

Dark-first Material 3. The reader, search and settings stay calm and plain;
the bold outlined style from the original mock (thick borders, hard shadows)
is used on the Library and Courses tabs (home and course cards).

- Motion tokens live in `lib/theme/motion.dart`.
- Cards and the search button open with the M3 container transform; other
  pages use shared-axis; search results use fade-through; the calendar slides
  between days, weeks and months with a shared-axis transition.
- M3 navigation bar with an animated indicator; tabs keep their state and
  cross-fade.
- Animations are skipped when the system "reduce motion" setting is on.

## Code layout

```
lib/
  core/       PDF-engine and storage interfaces, import/seed/delete service
  platform/   pdfrx engine and on-device file storage
  data/       models, the persisted store (library + courses + timetable)
  screens/    shell, library, courses, course space, calendar, reader, search, settings
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

To fill an empty app with a sample semester (for demos and screenshots):
`flutter run --dart-define=SEMESTA_DEMO=true`.

Native builds use [pdfrx](https://pub.dev/packages/pdfrx) (PDFium) and need a C
toolchain; see its README for the native build requirements.

The Inter font (SIL OFL 1.1) is bundled in `assets/fonts/`.
