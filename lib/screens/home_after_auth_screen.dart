import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/session_scope.dart';
import 'orders_selection_screen.dart';
import 'welcome_screen.dart';
import 'identify_screen.dart';

class HomeAfterAuthScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeAfterAuthScreen({super.key});

  @override
  State<HomeAfterAuthScreen> createState() => _HomeAfterAuthScreenState();
}

class _HomeAfterAuthScreenState extends State<HomeAfterAuthScreen> {
  bool _blockKeys = true;

  @override
  void initState() {
    super.initState();

    // Bloque ENTER/TAB pendant 1 seconde après l'arrivée sur l'écran
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _blockKeys = false);
    });
  }

  String _firstWord(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);
    const dark = Color(0xFF2B2B2B);

    final size = MediaQuery.sizeOf(context);
    final contentMaxWidth = size.width >= 600 ? 520.0 : size.width * 0.92;

    final scope = SessionScope.of(context);
    final orders = scope.orders.orders;

    final ordersCount = orders.length;

    String clientName = "Client";
    if (orders.isNotEmpty) {
      final raw = (orders.first.doCoord01 ?? '').toString().trim();
      final firstName = _firstWord(raw);

      if (firstName.isNotEmpty) {
        clientName = firstName;
      } else if (orders.first.ctNum.trim().isNotEmpty) {
        clientName = orders.first.ctNum.trim();
      }
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_blockKeys && event is KeyDownEvent) {
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.tab ||
              key == LogicalKeyboardKey.space) {
            return KeyEventResult.handled; // bloque temporairement
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _NoveLogoPlaceholder(
                    height: size.height * 0.12,
                    color: dark,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Bonjour $clientName",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: orange,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Vous avez $ordersCount commande${ordersCount > 1 ? 's' : ''} en cours",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.55),
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 34),
                          SizedBox(
                            width: double.infinity,
                            height: size.width >= 600 ? 62 : 56,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                OrdersSelectionScreen.routeName,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                "Voir mes commandes",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: size.width >= 600 ? 56 : 50,
                            child: ElevatedButton(
                              onPressed: () {
                                // On annule et on revient à l’identification
                                final store = SessionScope.of(context).orders;
                                store.clear();

                                Navigator.pushReplacementNamed(
                                  context,
                                  AuthScreen.routeName,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF2F2F2),
                                foregroundColor: orange,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                "Annuler",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Vous n'êtes pas $clientName ? ",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.35),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            WelcomeScreen.routeName,
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Se déconnecter",
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoveLogoPlaceholder extends StatelessWidget {
  final double height;
  final Color color;

  const _NoveLogoPlaceholder({
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logoNove.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
