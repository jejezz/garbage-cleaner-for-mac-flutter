import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'about_dialog.dart';

/// Opens the common About dialog with MacBroom's own copy. Called from the
/// nav rail's About button and the tray menu (about-dialog.md §1: a menubar-only
/// app has no app menu, so the tray menu takes its place).
Future<void> showMacBroomAbout(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppAboutDialog(
    context,
    tagline: l10n.aboutTagline,
    description: l10n.aboutDescription,
    features: [l10n.aboutFeatureScan, l10n.aboutFeatureUninstall, l10n.aboutFeatureDisk],
  );
}

/// The rest of the UI is English-only for now; OS language ko → Korean,
/// anything else → English (localization.md §3).
Locale resolveAppLocale(Locale? locale, Iterable<Locale> supported) =>
    locale?.languageCode == 'ko' ? const Locale('ko') : const Locale('en');

/// Material theme for the About dialog and the licenses page, which are
/// Material widgets inside the MacosApp. Matches the app's dark palette.
ThemeData aboutMaterialTheme({required Color seed, required Color surface}) => ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, surface: surface),
    );
