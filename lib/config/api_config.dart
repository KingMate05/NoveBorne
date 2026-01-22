class ApiConfig {
  static const host = 'api.nove.fr';

  // Auth n'a pas /api
  static const authPath = '/authentication-token';

  // Le reste est sous /api
  static const apiBasePath = '/api';

  static const defaultItemsPerPage = 10;
}
