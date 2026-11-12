import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

List<String> shardFiles(int index, int count) {
  final result = Process.runSync('bash', [
    'tool/test_files.sh',
    '$index',
    '$count',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return const LineSplitter().convert('${result.stdout}');
}

void main() {
  group('tool/test_files.sh', () {
    test('splits every test file into exactly one shard', () {
      final all =
          Directory('test')
              .listSync(recursive: true)
              .whereType<File>()
              .map((file) => file.path)
              .where((path) => path.endsWith('_test.dart'))
              .toList()
            ..sort();

      final shards = [
        for (var index = 0; index < 3; index++) shardFiles(index, 3),
      ];

      expect(shards.expand((files) => files).toList()..sort(), all);
      expect(shards.map((files) => files.length), everyElement(greaterThan(0)));
    });

    for (final arguments in [
      <String>[],
      ['0'],
      ['2', '2'],
      ['0', '0'],
      ['a', '2'],
    ]) {
      test('refuses the arguments $arguments', () {
        final result = Process.runSync('bash', [
          'tool/test_files.sh',
          ...arguments,
        ]);
        expect(result.exitCode, 64);
      });
    }
  });

  group('tool/merge_coverage.sh', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('coverage_'));
    tearDown(() => directory.deleteSync(recursive: true));

    File lcov(String name, String content) =>
        File('${directory.path}/$name')..writeAsStringSync(content);

    test('sums the hits of every shard by file and line', () {
      final first = lcov(
        'first.info',
        'SF:lib/core/a.dart\nDA:1,1\nDA:2,0\nLF:2\nLH:1\nend_of_record\n',
      );
      final second = lcov(
        'second.info',
        'SF:lib/core/a.dart\nDA:2,3\nDA:4,0\nLF:2\nLH:1\nend_of_record\n'
            'SF:lib/core/b.dart\nDA:7,2\nLF:1\nLH:1\nend_of_record\n',
      );
      final output = '${directory.path}/lcov.info';

      final result = Process.runSync('bash', [
        'tool/merge_coverage.sh',
        output,
        first.path,
        second.path,
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        File(output).readAsStringSync(),
        'SF:lib/core/a.dart\nDA:1,1\nDA:2,3\nDA:4,0\nLF:3\nLH:2\n'
        'end_of_record\n'
        'SF:lib/core/b.dart\nDA:7,2\nLF:1\nLH:1\nend_of_record\n',
      );
    });

    test('needs an output and at least one input', () {
      final result = Process.runSync('bash', [
        'tool/merge_coverage.sh',
        '${directory.path}/lcov.info',
      ]);
      expect(result.exitCode, 64);
    });
  });

  test('the CI runs as many test shards as TEST_SHARDS', () {
    final ci = loadYaml(
      File('.github/workflows/ci.yml').readAsStringSync(),
    ) as YamlMap;
    final shards = int.parse('${(ci['env'] as YamlMap)['TEST_SHARDS']}');
    final test = (ci['jobs'] as YamlMap)['test'] as YamlMap;
    final matrix = (test['strategy'] as YamlMap)['matrix'] as YamlMap;

    expect(matrix['shard'], [
      for (var index = 0; index < shards; index++) index,
    ]);
  });
}
