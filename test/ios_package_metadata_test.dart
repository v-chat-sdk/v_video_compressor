import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS package metadata', () {
    test('uses iOS 15 for SwiftPM and retains iOS 12 for CocoaPods', () {
      final packageManifest =
          File('ios/v_video_compressor/Package.swift').readAsStringSync();
      final podspec = File('ios/v_video_compressor.podspec').readAsStringSync();

      expect(packageManifest, contains('.iOS("15.0")'));
      expect(packageManifest, contains('FlutterFramework'));
      expect(podspec, contains("s.platform = :ios, '12.0'"));
      expect(podspec, contains("s.ios.deployment_target = '12.0'"));
    });

    test('example consistently targets iOS 15', () {
      final podfile = File('example/ios/Podfile').readAsStringSync();
      final appFrameworkInfo =
          File('example/ios/Flutter/AppFrameworkInfo.plist').readAsStringSync();
      final xcodeProject = File('example/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();

      expect(podfile, contains("platform :ios, '15.0'"));
      expect(appFrameworkInfo, contains('<string>15.0</string>'));

      final deploymentTargets = RegExp(
        r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);',
      ).allMatches(xcodeProject).map((match) => match.group(1)).toSet();
      expect(deploymentTargets, {'15.0'});
    });
  });
}
