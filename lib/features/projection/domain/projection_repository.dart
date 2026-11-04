import 'package:lar_em_dia/features/projection/domain/projection.dart';

abstract interface class ProjectionRepository {
  Future<Projection> fetch({required DateTime from, int months});
}
