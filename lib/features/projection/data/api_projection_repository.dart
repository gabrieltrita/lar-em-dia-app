import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/projection/data/projection_dtos.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

@LazySingleton(as: ProjectionRepository)
class ApiProjectionRepository implements ProjectionRepository {
  new(this._client);

  static const path = '/projection';

  final ApiClient _client;

  @override
  Future<Projection> fetch({required DateTime from, int months = 12}) async {
    final response = await _client.get<Projection>(
      path,
      decode: (data) => ProjectionDto.fromJson(data! as Json).toDomain(),
      query: {'from': Dates.toMonth(from), 'months': months},
    );
    return response.data;
  }
}
