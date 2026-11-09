import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

YamlMap readYaml(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

List<YamlMap> stepsOf(YamlMap job) =>
    (job['steps'] as YamlList).cast<YamlMap>();

YamlMap stepNamed(YamlMap job, String name) =>
    stepsOf(job).firstWhere((step) => step['name'] == name);

void main() {
  group('Android app', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    test('is published as dev.trita.laremdia', () {
      expect(gradle, contains('namespace = "dev.trita.laremdia"'));
      expect(gradle, contains('applicationId = "dev.trita.laremdia"'));
      expect(
        File('android/app/src/main/kotlin/dev/trita/laremdia/MainActivity.kt')
            .readAsStringSync(),
        startsWith('package dev.trita.laremdia\n'),
      );
    });

    test('reaches the internet in every build type', () {
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains(
          '<uses-permission android:name="android.permission.INTERNET"/>',
        ),
      );
    });

    test('signs releases with the upload key, never the debug key', () {
      expect(gradle, contains('rootProject.file("key.properties")'));
      for (final variable in [
        'ANDROID_KEYSTORE_PATH',
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_ALIAS',
        'ANDROID_KEY_PASSWORD',
      ]) {
        expect(gradle, contains('"$variable"'));
      }
      expect(gradle, contains('signingConfigs.getByName("release")'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(
        File('android/.gitignore').readAsStringSync(),
        allOf(contains('key.properties'), contains('**/*.jks')),
      );
    });
  });

  group('Android workflow', () {
    final workflow = readYaml('.github/workflows/android.yml');
    final bundle = (workflow['jobs'] as YamlMap)['bundle'] as YamlMap;

    test('builds from a version tag or by hand, after the CI', () {
      final on = workflow['on'] as YamlMap;
      expect((on['push'] as YamlMap)['tags'], ['[0-9]+.[0-9]+.[0-9]+']);
      expect(on.containsKey('workflow_dispatch'), isTrue);
      expect(bundle['needs'], 'ci');
      expect(
        stepNamed(bundle, 'Require the commit to be on main')['run'],
        r'git merge-base --is-ancestor "$GITHUB_SHA" origin/main',
      );
    });

    test('passes secrets as env data, never inside run', () {
      for (final step in stepsOf(bundle)) {
        expect('${step['run'] ?? ''}', isNot(contains(r'${{')));
      }
      final build = stepNamed(bundle, 'Build the app bundle');
      final env = build['env'] as YamlMap;
      expect(env['ANDROID_KEYSTORE_PATH'], r'${{ runner.temp }}/upload.jks');
      expect(env['ANDROID_KEY_ALIAS'], r'${{ secrets.ANDROID_KEY_ALIAS }}');
      expect(env['API_BASE_URL'], r'${{ vars.API_BASE_URL }}');
      expect(env['BUILD_NUMBER'], r'${{ github.run_number }}');
    });

    test('builds a release bundle for production and keeps it', () {
      final run = '${stepNamed(bundle, 'Build the app bundle')['run']}';
      expect(run, contains('flutter build appbundle --release'));
      expect(run, contains(r'--dart-define=API_BASE_URL="$API_BASE_URL"'));
      expect(run, contains(r'--dart-define=SITE_URL="https://$APP_HOST"'));
      expect(
        run,
        contains(r'--dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"'),
      );
      final upload = stepNamed(bundle, 'Upload the app bundle');
      expect(
        (upload['with'] as YamlMap)['path'],
        'build/app/outputs/bundle/release/app-release.aab',
      );
    });

    test('the CI builds a signed release with a throwaway key', () {
      final ci = readYaml('.github/workflows/ci.yml');
      final test = (ci['jobs'] as YamlMap)['test'] as YamlMap;
      const name = 'Build Android release with a throwaway key';
      final run = '${stepNamed(test, name)['run']}';
      expect(run, contains('keytool -genkeypair'));
      expect(run, contains('flutter build appbundle --release'));
      expect(run, contains('android.permission.INTERNET'));
    });
  });

  group('tool/android_keystore.sh', () {
    test('refuses extra arguments', () {
      final result = Process.runSync('bash', [
        'tool/android_keystore.sh',
        'a',
        'b',
        'c',
      ]);
      expect(result.exitCode, 64);
    });

    test('never overwrites an existing keystore', () {
      final existing = File(
        '${Directory.systemTemp.createTempSync('keystore_').path}/upload.jks',
      )..writeAsStringSync('keep me');
      addTearDown(() => existing.parent.deleteSync(recursive: true));

      final result = Process.runSync('bash', [
        'tool/android_keystore.sh',
        existing.path,
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('already exists'));
      expect(existing.readAsStringSync(), 'keep me');
    });

    test('stores the four secrets without printing the password', () {
      final script = File('tool/android_keystore.sh').readAsStringSync();
      for (final secret in [
        'ANDROID_KEYSTORE_BASE64',
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_PASSWORD',
        'ANDROID_KEY_ALIAS',
      ]) {
        expect(script, contains('gh secret set $secret --repo'));
      }
      expect(script, contains('-storepass:env ANDROID_KEY_PASSWORD'));
      expect(script, isNot(contains('--body')));
    });
  });
}
