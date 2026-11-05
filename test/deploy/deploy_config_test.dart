import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

YamlMap readYaml(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

void main() {
  final workflow = readYaml('.github/workflows/deploy.yml');
  final staging = (workflow['jobs'] as YamlMap)['staging'] as YamlMap;
  final env = staging['env'] as YamlMap;
  final steps = (staging['steps'] as YamlList).cast<YamlMap>();

  YamlMap step(String name) => steps.firstWhere((step) => step['name'] == name);

  group('Deploy workflow', () {
    test('deploys staging from main after the reusable CI', () {
      final on = workflow['on'] as YamlMap;
      expect((on['push'] as YamlMap)['branches'], ['main']);
      expect(on.containsKey('workflow_dispatch'), isTrue);
      expect(staging['needs'], 'ci');
      expect(staging['if'], contains("github.ref == 'refs/heads/main'"));
      expect(staging['if'], contains("vars.STAGING_DEPLOY_HOST != ''"));

      final ci = readYaml('.github/workflows/ci.yml');
      expect((ci['on'] as YamlMap).containsKey('workflow_call'), isTrue);
    });

    test('builds the web app against the staging API', () {
      expect(env['API_BASE_URL'], r'${{ vars.STAGING_API_BASE_URL }}');
      expect(
        step('Build web')['run'],
        contains(r'--dart-define=API_BASE_URL="$API_BASE_URL"'),
      );
    });

    test('runs kamal setup by hand and kamal deploy on push', () {
      expect(
        env['KAMAL_COMMAND'],
        r"${{ github.event_name == 'workflow_dispatch' "
        "&& 'setup' || 'deploy' }}",
      );
      expect(step('Deploy')['run'], r'kamal "$KAMAL_COMMAND" -d staging');
    });

    test('keeps the SSH key in one step and out of every script', () {
      final configure = step('Configure SSH');
      expect((configure['env'] as YamlMap).keys, [
        'SSH_PRIVATE_KEY',
        'SSH_KNOWN_HOSTS',
      ]);
      expect(configure['run'], contains('StrictHostKeyChecking yes'));
      expect(env.keys.where((key) => '$key'.startsWith('SSH_')), isEmpty);
      for (final step in steps) {
        expect('${step['run'] ?? ''}', isNot(contains(r'${{')));
      }
    });

    test('builds arm64 images through QEMU only for arm64 servers', () {
      expect(
        step('Set up QEMU for arm64 images')['if'],
        "env.DEPLOY_ARCH == 'arm64'",
      );
    });
  });

  group('Kamal configuration', () {
    final config = File('config/deploy.yml').readAsStringSync();

    test('serves the local build behind kamal-proxy with TLS', () {
      expect(config, contains('context: .'));
      expect(config, contains('ssl: true'));
      expect(config, contains('app_port: 80'));
      expect(config, contains('path: /up'));
      expect(
        File('config/deploy.staging.yml').readAsStringSync(),
        contains('service: laremdia-web-staging'),
      );
    });

    test('only ships the web build and the nginx configuration', () {
      expect(File('.dockerignore').readAsLinesSync(), [
        '*',
        '!build/web',
        '!deploy/nginx.conf',
      ]);
    });

    test('answers the health check and falls back to index.html', () {
      final nginx = File('deploy/nginx.conf').readAsStringSync();
      expect(nginx, contains('location = /up'));
      expect(nginx, contains(r'try_files $uri $uri/ /index.html;'));
      expect(nginx, contains('Cache-Control "no-cache"'));
    });

    test('keeps only references in the Kamal secrets', () {
      for (final file in ['.kamal/secrets', '.kamal/secrets.staging']) {
        expect(
          File(file).readAsStringSync(),
          'KAMAL_REGISTRY_PASSWORD=\$KAMAL_REGISTRY_PASSWORD\n',
        );
      }
    });
  });
}
