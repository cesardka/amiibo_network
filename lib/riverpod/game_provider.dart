import 'package:amiibo_network/model/amiibo.dart';
import 'package:amiibo_network/model/game.dart';
import 'package:amiibo_network/riverpod/amiibo_provider.dart';
import 'package:amiibo_network/utils/urls_constants.dart' show apiUrl;
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:stash/stash_api.dart';
import 'package:stash_dio/stash_dio.dart';

final cacheProvider = Provider<Cache>((_) => throw UnimplementedError());

final _dioProvider = Provider<Dio>((ref) {
  final hiveCache = ref.watch(cacheProvider);
  final stashOptions = hiveCache.interceptor('amiibo');

  final dio = Dio(
    BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: 5000,
    ),
  );

  return dio..interceptors.add(stashOptions);
});

final _characterProvider = StreamProvider.autoDispose.family<Amiibo?, int>(
  (ref, key) => ref
      .watch(detailAmiiboProvider(key).stream)
      .map<Amiibo?>((cb) => cb?.copyWith(owned: false, wishlist: false))
      .distinct(),
  name: 'Character Provider',
);

final gameProvider =
    FutureProvider.autoDispose.family<NintendoPlatform, int>((ref, key) async {
  final amiibo = await ref.watch(_characterProvider(key).future);
  if (amiibo == null) return const NintendoPlatform();
  final dio = ref.watch(_dioProvider);
  final token = CancelToken();

  ref.onDispose(token.cancel);
  late final Response<Map<String, dynamic>> result;

  if (amiibo.id != null) {
    final String head = amiibo.id!.substring(0, 8);
    final String tail = amiibo.id!.substring(8);
    result = await dio.get<Map<String, dynamic>>(
      'amiibo/?head=$head&tail=$tail&showusage',
      cancelToken: token,
    );
  } else
    result = await dio.get<Map<String, dynamic>>(
      'amiibo/?character=${amiibo.character}&showusage',
      cancelToken: token,
    );

  if (result.data == null) throw ArgumentError();
  final data = result.data!['amiibo'];
  if (data is! List<dynamic> || data.length > 1) throw ArgumentError();
  final single = data.first as Map<String, dynamic>;
  final NintendoPlatform platform = NintendoPlatform.fromJson(single);
  ref.maintainState = true;
  return platform;
}, name: 'Games Provider');
