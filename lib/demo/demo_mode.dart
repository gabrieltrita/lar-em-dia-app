import 'package:dio/dio.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/demo/demo_adapter.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';

abstract final class DemoMode {
  static final adapter = DemoAdapter(
    DemoServer(DemoSeed.build(DateTime.now())),
  );

  static Dio apply(Dio dio, {bool enabled = Env.demo}) =>
      enabled ? (dio..httpClientAdapter = adapter) : dio;
}
