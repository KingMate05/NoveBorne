import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/orders_service.dart';
import 'state/app_session.dart';
import 'state/orders_store.dart';
import 'widgets/session_scope.dart';
import 'models/order.dart';

import 'screens/welcome_screen.dart';
import 'screens/identify_screen.dart';
import 'screens/home_after_auth_screen.dart';
import 'screens/orders_selection_screen.dart';
import 'screens/orders_recap_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiClient api;
  late final AppSession session;
  late final OrdersStore orders;

  @override
  void initState() {
    super.initState();
    api = ApiClient();
    session = AppSession(api: api, auth: AuthService(api));
    orders = OrdersStore(ordersService: OrdersService(api));

    // init au démarrage
    session.init();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      orders: orders,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: WelcomeScreen.routeName,
        routes: {
          WelcomeScreen.routeName: (_) => const WelcomeScreen(),
          AuthScreen.routeName: (_) => const AuthScreen(),
          HomeAfterAuthScreen.routeName: (_) => const HomeAfterAuthScreen(),
          OrdersSelectionScreen.routeName: (_) => const OrdersSelectionScreen(),
          // ⚠️ OrdersRecapScreen PAS ici (car arguments)
        },
        onGenerateRoute: (settings) {
          if (settings.name == OrdersRecapScreen.routeName) {
            final selectedOrders = settings.arguments as List<OrderHeader>;

            return MaterialPageRoute(
              builder: (_) => OrdersRecapScreen(selectedOrders: selectedOrders),
            );
          }

          return null;
        },
      ),
    );
  }
}
