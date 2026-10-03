# Show HN draft

**Title** (max 80 chars)

```
Show HN: MacBroom – an open-source CleanMyMac alternative built with Flutter
```

**URL:** https://github.com/jejezz/macbroom-flutter

**First comment** (HN convention: submit the URL, then post this as the first comment)

```
Hi HN, I'm the author of MacBroom, a small menubar app for macOS that does the
three things I actually used CleanMyMac for: clear caches and developer build
junk, uninstall apps together with their leftovers in ~/Library, and show how
full the disk is. It's free and MIT-licensed.

Repo: https://github.com/jejezz/macbroom-flutter
Download: https://github.com/jejezz/macbroom-flutter/releases/latest

Why I built it: I'm a Flutter developer and my Mac was carrying ~40 GB of
Xcode DerivedData, iOS simulators, Gradle and pub caches that CleanMyMac
mostly doesn't know about. A shell script would have solved it, but I wanted
to see how far Flutter goes for a "real" macOS utility.

What's interesting technically:

- It's ~1,400 lines of Dart and ~100 lines of Swift. The Swift is a single
  MethodChannel handler for the things Dart genuinely can't do: move files
  to the Trash (FileManager.trashItem, so everything is reversible), check
  Full Disk Access, read volume capacity the way Finder does (purgeable
  space counts as free), and read bundle IDs.
- Scanning uses `du -sk` instead of walking the tree in Dart. ~/Library/Caches
  alone can hold 500k files; du is 5-10x faster than stat()-ing from Dart.
- Junk categories are one declarative list (scan_targets.dart). Adding a
  category is a 10-line entry, no other code changes.
- App leftovers are matched by bundle ID, including the vendor/product
  nesting some apps use (Application Support/Google/Chrome).
- Menubar behaviour (tray icon, popover under the icon, hide-on-blur) comes
  from tray_manager + window_manager, so no NSStatusItem code of my own.

Honest limitations:

- Not notarized yet - I don't have a Developer ID, so the build is ad-hoc
  signed and you have to right-click -> Open the first time. The release
  script already supports Developer ID + notarytool when I get one.
- Because of that, Full Disk Access has to be re-granted after every update
  (macOS sees each ad-hoc build as a new app).
- Not App Store-eligible by design; the sandbox is off so it can reach other
  apps' caches. Same constraint CleanMyMac has.
- The ~43 MB app size is mostly the Flutter engine. A SwiftUI version would
  be a fraction of that; I chose Flutter for the UI iteration speed.

Happy to answer questions about Flutter on macOS desktop, the TCC/Full Disk
Access dance, or what other junk categories people would want.
```

## Posting notes

- Best slot: weekdays 8–10 am US Eastern (9–11 pm KST).
- The first hour matters most — answer comments quickly. Likely questions:
  "why not Swift/SwiftUI?", "how is this different from `rm -rf ~/Library/Caches`?",
  "why `du` instead of APFS APIs?", "app size".
- No marketing words ("free", "best") in the title — HN guidelines.
