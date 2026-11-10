import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

YamlMap readYaml(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

void main() {
  final workflow = readYaml('.github/workflows/deploy.yml');
  final jobs = workflow['jobs'] as YamlMap;
  final staging = jobs['staging'] as YamlMap;
  final production = jobs['production'] as YamlMap;
  final action = readYaml('.github/actions/web-deploy/action.yml');
  final actionSteps = ((action['runs'] as YamlMap)['steps'] as YamlList)
      .cast<YamlMap>();

  YamlMap actionStep(String name) =>
      actionSteps.firstWhere((step) => step['name'] == name);

  YamlMap deployWith(YamlMap job) =>
      (job['steps'] as YamlList).cast<YamlMap>().firstWhere(
            (step) => step['uses'] == './.github/actions/web-deploy',
          )['with']
          as YamlMap;

  group('Deploy workflow', () {
    test('deploys staging from main and production from a version tag', () {
      final on = workflow['on'] as YamlMap;
      final push = on['push'] as YamlMap;
      expect(push['branches'], ['main']);
      expect(push['tags'], ['[0-9]+.[0-9]+.[0-9]+']);
      final dispatch = on['workflow_dispatch'] as YamlMap;
      final environment =
          (dispatch['inputs'] as YamlMap)['environment'] as YamlMap;
      expect(environment['options'], ['staging', 'production']);

      expect(staging['needs'], 'ci');
      expect(staging['if'], contains("vars.STAGING_DEPLOY_HOST != ''"));
      expect(staging['if'], contains("github.ref_type == 'branch'"));
      expect(staging['if'], contains("inputs.environment == 'staging'"));

      expect(production['needs'], 'ci');
      expect(production['if'], contains("vars.DEPLOY_HOST != ''"));
      expect(production['if'], contains("github.ref_type == 'tag'"));
      expect(production['if'], contains("inputs.environment == 'production'"));

      final ci = readYaml('.github/workflows/ci.yml');
      expect((ci['on'] as YamlMap).containsKey('workflow_call'), isTrue);
    });

    test('only deploys a production tag that is on main', () {
      final steps = (production['steps'] as YamlList).cast<YamlMap>();
      final guard = steps.firstWhere(
        (step) => step['name'] == 'Require the tagged commit to be on main',
      );
      expect(
        guard['run'],
        r'git merge-base --is-ancestor "$GITHUB_SHA" '
        'origin/main',
      );
    });

    test('keeps staging and production settings apart', () {
      final stagingWith = deployWith(staging);
      final productionWith = deployWith(production);

      expect(stagingWith['destination'], 'staging');
      expect(stagingWith['app-host'], r'${{ vars.STAGING_APP_HOST }}');
      expect(stagingWith['api-base-url'], r'${{ vars.STAGING_API_BASE_URL }}');
      expect(
        stagingWith['google-client-id'],
        r'${{ vars.STAGING_GOOGLE_CLIENT_ID }}',
      );
      expect(stagingWith['indexable'], 'false');
      expect(
        stagingWith['ssh-private-key'],
        r'${{ secrets.STAGING_DEPLOY_SSH_PRIVATE_KEY }}',
      );

      expect(productionWith.containsKey('destination'), isFalse);
      expect(productionWith['app-host'], r'${{ vars.APP_HOST }}');
      expect(productionWith['api-base-url'], r'${{ vars.API_BASE_URL }}');
      expect(
        productionWith['google-client-id'],
        r'${{ vars.GOOGLE_CLIENT_ID }}',
      );
      expect(productionWith['indexable'], 'true');
      expect(
        productionWith['ssh-private-key'],
        r'${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}',
      );

      for (final job in [staging, production]) {
        final env = job['env'] as YamlMap;
        expect('${env['DEPLOY_HOST']}', contains('DEPLOY_HOST'));
        expect('${env['APP_HOST']}', contains('APP_HOST'));
        expect(
          deployWith(job)['setup'],
          r"${{ github.event_name == 'workflow_dispatch' }}",
        );
      }
    });
  });

  group('Web deploy action', () {
    test('prepares the search engine files before the build', () {
      final names = actionSteps.map((step) => step['name']).toList();
      expect(
        names.indexOf('Prepare search engine files'),
        lessThan(names.indexOf('Build web')),
      );
      expect(
        actionStep('Prepare search engine files')['run'],
        r'tool/prepare_web_build.sh web "https://$APP_HOST" "$INDEXABLE"',
      );
    });

    test('fills the API origin into the security headers before deploying', () {
      final step = actionStep('Prepare security headers');
      expect(
        step['run'],
        'tool/prepare_web_headers.sh deploy/security-headers.conf '
        r'"$API_BASE_URL"',
      );
      expect(
        (step['env'] as YamlMap)['API_BASE_URL'],
        r'${{ inputs.api-base-url }}',
      );
    });

    test('builds the web app against the API of the environment', () {
      expect(
        (actionStep('Build web')['env'] as YamlMap)['API_BASE_URL'],
        r'${{ inputs.api-base-url }}',
      );
      expect(
        actionStep('Build web')['run'],
        contains(r'--dart-define=API_BASE_URL="$API_BASE_URL"'),
      );
      expect(
        (actionStep('Build web')['env'] as YamlMap)['GOOGLE_CLIENT_ID'],
        r'${{ inputs.google-client-id }}',
      );
      expect(
        actionStep('Build web')['run'],
        contains(r'--dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"'),
      );
    });

    test('runs kamal setup when asked and kamal deploy otherwise', () {
      final run = '${actionStep('Deploy')['run']}';
      expect(
        run,
        contains(r'if [ "$SETUP" = "true" ]; then command=setup; fi'),
      );
      expect(
        run,
        contains(r'kamal "$command" ${DESTINATION:+-d "$DESTINATION"}'),
      );
    });

    test('keeps the SSH key in one step and out of every script', () {
      final configure = actionStep('Configure SSH');
      expect((configure['env'] as YamlMap).keys, [
        'SSH_PRIVATE_KEY',
        'SSH_KNOWN_HOSTS',
      ]);
      expect(configure['run'], contains('StrictHostKeyChecking yes'));
      for (final step in actionSteps) {
        expect('${step['run'] ?? ''}', isNot(contains(r'${{')));
      }
      for (final job in [staging, production]) {
        final env = job['env'] as YamlMap;
        expect(env.keys.where((key) => '$key'.startsWith('SSH_')), isEmpty);
        for (final step in (job['steps'] as YamlList).cast<YamlMap>()) {
          expect('${step['run'] ?? ''}', isNot(contains(r'${{')));
        }
      }
    });

    test('builds arm64 images through QEMU only for arm64 servers', () {
      expect(
        actionStep('Set up QEMU for arm64 images')['if'],
        "env.DEPLOY_ARCH == 'arm64'",
      );
    });
  });

  group('Kamal configuration', () {
    final config = File('config/deploy.yml').readAsStringSync();

    test('serves the local build behind kamal-proxy with TLS', () {
      expect(config, contains('service: laremdia-web\n'));
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
        '!deploy/security-headers.conf',
      ]);
    });

    test('lets every file the Dockerfile copies into the build context', () {
      final allowed = File('.dockerignore')
          .readAsLinesSync()
          .where((line) => line.startsWith('!'))
          .map((line) => line.substring(1))
          .toSet();
      final sources = RegExp(r'^COPY (\S+) ', multiLine: true)
          .allMatches(File('Dockerfile').readAsStringSync())
          .map((match) => match.group(1)!)
          .toList();

      expect(sources, isNotEmpty);
      for (final source in sources) {
        expect(allowed, contains(source), reason: source);
      }
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
