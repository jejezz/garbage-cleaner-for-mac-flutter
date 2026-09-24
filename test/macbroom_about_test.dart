// The common About dialog is Material; MacBroom runs in a MacosApp
// (CupertinoApp underneath). Checks the dialog and licenses page still open
// there with the delegates and theme main.dart passes.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LicensePage, Theme, ThemeMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garbage_cleaner_for_mac/about/macbroom_about.dart';
import 'package:garbage_cleaner_for_mac/app_identity.dart';
import 'package:garbage_cleaner_for_mac/l10n/app_localizations.dart';
import 'package:garbage_cleaner_for_mac/theme/broom_theme.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

Widget _app(Locale locale) => MacosApp(
      locale: locale,
      theme: MacosThemeData.dark(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveAppLocale,
      builder: (context, child) => Theme(
        data: aboutMaterialTheme(seed: Broom.violet, surface: Broom.bg1),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Center(
          child: GestureDetector(onTap: () => showMacBroomAbout(context), child: const Text('open')),
        ),
      ),
    );

void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: AppIdentity.displayName,
        packageName: 'art.zoomon.macbroom',
        version: '1.0.3',
        buildNumber: '4',
        buildSignature: '',
      ));

  testWidgets('opens from a MacosApp with version and features (ko)', (tester) async {
    await tester.pumpWidget(_app(const Locale('ko')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('버전 1.0.3 (빌드 4)'), findsOneWidget);
    expect(find.text('무료 오픈소스 macOS 정리 도구'), findsOneWidget);
    expect(find.text(AppIdentity.copyright), findsOneWidget);
  });

  testWidgets('licenses page opens (en)', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Source Licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('non-Korean OS languages fall back to English', () {
    expect(resolveAppLocale(const Locale('ja'), AppLocalizations.supportedLocales), const Locale('en'));
    expect(resolveAppLocale(const Locale('ko', 'KR'), AppLocalizations.supportedLocales), const Locale('ko'));
  });
}
