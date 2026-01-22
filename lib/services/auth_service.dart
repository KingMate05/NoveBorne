import '../config/api_config.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client;
  AuthService(this._client);

  Future<String> loginAdmin({required String password}) async {
    final json = await _client.postJson(
      ApiConfig.authPath,
      body: {
        'identifier': 'admin',
        'password': password,
      },
    );
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('Token manquant dans la réponse auth');
    }
    return token;
  }
}
