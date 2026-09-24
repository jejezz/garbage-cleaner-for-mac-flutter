// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutTooltip => 'About';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => 'Close';

  @override
  String aboutMenuItem(String appName) {
    return 'About $appName';
  }

  @override
  String get aboutTagline => 'A free, open-source cleaner for macOS';

  @override
  String get aboutDescription =>
      'A one-click menubar app that clears caches and developer junk, uninstalls apps with their leftovers, and shows disk usage. Everything is moved to the Trash, so it\'s reversible.';

  @override
  String get aboutFeatureScan =>
      'Smart Scan: junk by category with a safety rating';

  @override
  String get aboutFeatureUninstall =>
      'Uninstaller: removes apps with their leftovers in ~/Library';

  @override
  String get aboutFeatureDisk => 'Disk gauge: Finder-accurate usage ring';
}
