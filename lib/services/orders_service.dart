import '../config/api_config.dart';
import '../models/order.dart';
import 'api_client.dart';

class OrdersService {
  final ApiClient _client;
  OrdersService(this._client);

  Future<OrderResponse> getOrdersByClient({
    required String doTiers,
    int page = 1,
    int itemsPerPage = ApiConfig.defaultItemsPerPage,
  }) async {
    final json = await _client.getJson(
      '${ApiConfig.apiBasePath}/f_docentetes',
      query: {
        'doType[]': 2,
        'page': page,
        'itemsPerPage': itemsPerPage,
        'doTiers': doTiers,
        'order[cbmarq]': 'desc',
      },
    );

    return OrderResponse.fromJson(json);
  }

  Future<OrderResponse> searchOrders({
    required String keyword,
    int page = 1,
    int itemsPerPage = ApiConfig.defaultItemsPerPage,
  }) async {
    final json = await _client.getJson(
      '${ApiConfig.apiBasePath}/f_docentetes',
      query: {
        'doType[]': 2,
        'keywords': keyword,
        'page': page,
        'itemsPerPage': itemsPerPage,
      },
    );

    return OrderResponse.fromJson(json);
  }
}
