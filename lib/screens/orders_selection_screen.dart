import 'package:flutter/material.dart';

import '../widgets/session_scope.dart';
import 'orders_recap_screen.dart';
import 'identify_screen.dart';

class OrdersSelectionScreen extends StatelessWidget {
  static const routeName = '/orders';

  const OrdersSelectionScreen({super.key});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
    // (je reste simple, sans intl)
  }

  String _formatMoney2(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    // Certains JSON renvoient "16.410000" (point), on gère aussi la virgule au cas où
    final normalized = s.replaceAll(',', '.');

    final v = double.tryParse(normalized);
    if (v == null) return '';

    // 2 décimales
    final out = v.toStringAsFixed(2);

    // Affichage FR: virgule
    return out.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    final size = MediaQuery.sizeOf(context);
    final contentMaxWidth = size.width >= 600 ? 560.0 : size.width * 0.92;

    final store = SessionScope.of(context).orders;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 28, 13, 28),
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
              child: const Text(
                "Choisissez la commande à préparer",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            // Subheader
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Text(
                  "Vous pouvez sélectionner une ou plusieurs\ncommandes",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // List (branchée au store)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: AnimatedBuilder(
                    animation: store,
                    builder: (context, _) {
                      if (store.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (store.orders.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              "Aucune commande trouvée.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        itemCount: store.orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final order = store.orders[index];
                          final isChecked =
                              store.selectedPieces.contains(order.doPiece);

                          final dateText = _formatDate(order.doDate);
                          final totalText = _formatMoney2(order.doTotalttc);

                          return _OrderCard(
                            orderId: order.displayOrderId,
                            dateText: dateText.isEmpty ? "-" : dateText,
                            totalText: totalText.isEmpty ? "-" : totalText,
                            isSelected: isChecked,
                            onTap: () => store.toggleSelected(order.doPiece),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: AnimatedBuilder(
                  animation: store,
                  builder: (context, _) {
                    final canContinue = store.selectedPieces.isNotEmpty;
                    final count = store.selectedPieces.length;

                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: size.width >= 600 ? 64 : 56,
                          child: ElevatedButton(
                            onPressed: canContinue
                                ? () {
                                    final selectedOrders = store.selectedOrders;

                                    Navigator.pushNamed(
                                      context,
                                      OrdersRecapScreen.routeName,
                                      arguments: selectedOrders,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: orange.withOpacity(0.30),
                              disabledForegroundColor:
                                  Colors.white.withOpacity(0.85),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              canContinue
                                  ? "Récupérer les commandes\nsélectionnées ($count)"
                                  : "Récupérer les commandes\nsélectionnées",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryPill(
                                label: "Retour",
                                onTap: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SecondaryPill(
                                label: "Changer client",
                                onTap: () {
                                  store.clear();
                                  Navigator.pushReplacementNamed(
                                    context,
                                    AuthScreen.routeName,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final String dateText;
  final String totalText;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderCard({
    required this.orderId,
    required this.dateText,
    required this.totalText,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: orange, width: 1.6),
          ),
          child: Row(
            children: [
              _CheckSquare(isChecked: isSelected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Commande $orderId",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: orange,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.black.withOpacity(0.55),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Passée le $dateText",
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      totalText == "-" ? "Total : -" : "Total : $totalText€",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.60),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  final bool isChecked;
  const _CheckSquare({required this.isChecked});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isChecked ? orange : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: orange, width: 1.6),
      ),
      child: isChecked
          ? const Icon(Icons.check, color: Colors.white, size: 28)
          : null,
    );
  }
}

class _SecondaryPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryPill({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: orange,
          side: BorderSide(color: orange.withOpacity(0.0)),
          backgroundColor: const Color(0xFFF2F2F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
