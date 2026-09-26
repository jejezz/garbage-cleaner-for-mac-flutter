// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aboutTooltip => '정보';

  @override
  String aboutVersion(String version, String build) {
    return '버전 $version (빌드 $build)';
  }

  @override
  String get aboutOpenSourceLicenses => '오픈소스 라이선스';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => '닫기';

  @override
  String aboutMenuItem(String appName) {
    return '$appName 정보';
  }

  @override
  String get aboutTagline => '무료 오픈소스 macOS 정리 도구';

  @override
  String get aboutDescription =>
      '메뉴 막대에서 한 번에 캐시와 개발 도구 찌꺼기를 치우고, 앱을 남은 파일까지 함께 지우며, 디스크 사용량을 보여 줍니다. 찌꺼기 파일은 휴지통을 거치지 않고 완전히 삭제하며, 제거한 앱은 휴지통으로 옮깁니다.';

  @override
  String get aboutFeatureScan => '스마트 스캔: 안전 등급과 함께 분류별로 정크 찾기';

  @override
  String get aboutFeatureUninstall => '앱 제거: ~/Library에 남은 파일까지 함께 삭제';

  @override
  String get aboutFeatureDisk => '디스크 게이지: Finder와 같은 기준의 사용량 표시';
}
