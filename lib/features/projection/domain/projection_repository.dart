import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

abstract interface class ProjectionRepository {
  Future<Projection> fetch({required DateTime from, ProjectionPeriod period});

  Future<ProjectionComparison> simulate(
    List<EntryPlan> plans, {
    required DateTime from,
    int months,
  });
}
