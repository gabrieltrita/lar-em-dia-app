import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/api_entry_repository.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/data/projection_dtos.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

@LazySingleton(as: ProjectionRepository)
class ApiProjectionRepository implements ProjectionRepository {
  new(this._client, this._cache);

  static const path = '/projection';
  static const simulationPath = '/projection/simulation';
  static const marginMonths = 6;

  final ApiClient _client;
  final FinanceCache _cache;

  @override
  Future<Projection> fetch({
    required DateTime from,
    ProjectionPeriod period = ProjectionPeriod.year,
  }) async {
    if (_cache.projection(from, period) case final Projection cached) {
      return cached;
    }
    final months = period.months;
    final query = months == null
        ? {'from': Dates.toMonth(from), 'months': period.query}
        : {
            'from': Dates.toMonth(Dates.addMonths(from, -marginMonths)),
            'months': '${months + 2 * marginMonths}',
          };
    final generation = _cache.generation;
    final projection = await _cache.once(
      'projection:${query['from']}:${query['months']}',
      () async {
        final response = await _client.get<Projection>(
          path,
          decode: (data) => ProjectionDto.fromJson(data! as Json).toDomain(),
          query: query,
        );
        if (generation == _cache.generation) {
          _cache.storeProjection(response.data);
        }
        return response.data;
      },
    );
    return FinanceCache.slice(projection, from, period)!;
  }

  @override
  Future<ProjectionComparison> simulate(
    List<EntryPlan> plans, {
    required DateTime from,
    int months = 12,
  }) async {
    final response = await _client.post<ProjectionComparison>(
      simulationPath,
      decode: (data) =>
          ProjectionComparisonDto.fromJson(data! as Json).toDomain(),
      body: {
        'from': Dates.toMonth(from),
        'months': months,
        'entries': [
          for (final plan in plans) ApiEntryRepository.planBody(plan),
        ],
      },
    );
    return response.data;
  }
}
