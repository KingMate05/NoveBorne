import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/orders_service.dart';

import 'state/app_session.dart';
import 'state/orders_store.dart';

import 'widgets/session_scope.dart';
import 'widgets/global_scan_listener.dart';

import 'models/order.dart';

import 'screens/welcome_screen.dart';
import 'screens/identify_screen.dart';
import 'screens/home_after_auth_screen.dart';
import 'screens/orders_selection_screen.dart';
import 'screens/orders_recap_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Cache la barre Android (nav + status) en mode borne
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiClient api;
  late final AppSession session;
  late final OrdersStore orders;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  // ✅ Anti double-scan (verrou métier)
  bool _scanBusy = false;

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
        navigatorKey: _navKey,
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

        // ✅ listener global scan
        builder: (context, child) {
          return GlobalScanListener(
            child: child ?? const SizedBox.shrink(),
            onScan: (raw) async {
              // ✅ Verrou: si un scan est déjà en cours, on ignore
              if (_scanBusy) return;
              _scanBusy = true;

              try {
                final scope = SessionScope.of(context);
                final orders = scope.orders;

                final trimmed = raw.trim();
                if (trimmed.isEmpty) return;

                final decoded = jsonDecode(trimmed);
                if (decoded is! Map) return;

                final m = decoded.cast<String, dynamic>();
                final doPiece = m['doPiece']?.toString().trim();
                final ctNum = (m['ctNum'] ?? m['client'])?.toString().trim();

                if (doPiece != null && doPiece.isNotEmpty) {
                  await orders.loadByKeyword(doPiece);
                  if (orders.orders.isEmpty) return;

                  orders.selectedPieces
                    ..clear()
                    ..add(orders.orders.first.doPiece);

                  _navKey.currentState?.pushNamedAndRemoveUntil(
                    HomeAfterAuthScreen.routeName,
                    (route) => false,
                  );
                  return;
                }

                if (ctNum != null && ctNum.isNotEmpty) {
                  await orders.loadByClient(ctNum);
                  if (orders.orders.isEmpty) return;

                  _navKey.currentState?.pushNamedAndRemoveUntil(
                    HomeAfterAuthScreen.routeName,
                    (route) => false,
                  );
                  return;
                }
              } catch (_) {
                // ignore: QR invalide
              } finally {
                _scanBusy = false; // ✅ on libère le verrou quoi qu'il arrive
              }
            },
          );
        },
      ),
    );
  }
}
