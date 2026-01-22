// lib/screens/orders_recap_screen.dart
import 'package:flutter/material.dart';

import '../models/order.dart';
import '../widgets/session_scope.dart';
import 'welcome_screen.dart';

class OrdersRecapScreen extends StatelessWidget {
  static const routeName = '/recap';

  final List<OrderHeader> selectedOrders;

  const OrdersRecapScreen({
    super.key,
    required this.selectedOrders,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    final size = MediaQuery.sizeOf(context);
    final contentMaxWidth = size.width >= 600 ? 560.0 : size.width * 0.92;

    final orders = selectedOrders;

    // Ex: "Commande 1, 2" (affichage léger comme maquette)
    final ordersLabel =
        orders.isEmpty ? "" : orders.map((o) => o.displayOrderId).join(", ");

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header (ombre)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
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
                "Produits des commandes\nsélectionnées",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Sous-titre (Commande {nb}, {nb})
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Text(
                  ordersLabel.isEmpty ? "Commande" : "Commande $ordersLabel",
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Liste groupée par commande
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderSection(order: order);
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
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: size.width >= 600 ? 64 : 56,
                      child: ElevatedButton(
                        onPressed: () {
                          // Reset session UI: on nettoie les selections + liste
                          final store = SessionScope.of(context).orders;
                          store.clear();

                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            WelcomeScreen.routeName,
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Récupérer au comptoir",
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: size.width >= 600 ? 58 : 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: orange,
                          side: const BorderSide(color: orange, width: 1.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Retour aux commandes",
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
          ],
        ),
      ),
    );
  }
}

class _OrderSection extends StatelessWidget {
  final OrderHeader order;

  const _OrderSection({required this.order});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    final orderId = order.displayOrderId;
    final lines = order.lines;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Commande $orderId",
            style: const TextStyle(
              color: orange,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Aucun produit trouvé pour cette commande.",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.45),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...lines.map((l) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductTile(line: l),
              );
            }).toList(),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final OrderLine line;

  const _ProductTile({required this.line});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    final name = line.dlDesign;
    final qty = _formatQtySmart(line.dlQte);
    final unitPrice = _formatMoney2(line.dlPrixunitaire);
    final imageUrl = _buildImageUrl(line);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Thumb(imageUrl: imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: orange,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Quantité : $qty",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Prix unitaire : $unitPrice€",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney2(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '-';
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return '-';
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatQtySmart(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '-';

    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return '-';

    // Si c'est un entier (ex: 1.0, 2.0)
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }

    // Sinon, on garde une décimale ou deux max, format FR
    String out;

    // On limite à 2 décimales pour éviter 1.333333
    out = v.toStringAsFixed(2);

    // On enlève les zéros inutiles: 1.50 -> 1.5, 1.00 -> 1
    out = out.replaceAll(RegExp(r'0+$'), '');
    out = out.replaceAll(RegExp(r'\.$'), '');

    // Format FR
    return out.replaceAll('.', ',');
  }

  String? _buildImageUrl(OrderLine line) {
    final arRef = line.arRef.trim();
    if (arRef.isEmpty) return null;
    if (line.images.isEmpty) return null;

    final first = line.images.first;
    final name = first.name.trim();
    if (name.isEmpty) return null;

    final sizes = first.sizes;
    int chosen = 280;
    if (sizes.isNotEmpty) {
      if (sizes.contains(280)) {
        chosen = 280;
      } else if (sizes.contains(420)) {
        chosen = 420;
      } else if (sizes.contains(60)) {
        chosen = 60;
      } else {
        chosen = sizes.first;
      }
    }

    return "https://api.nove.fr/DATA/fArticle/images/$arRef/sizes/${chosen}_$name";
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;

  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    debugPrint("IMG URL = $imageUrl");

    final placeholder = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFE3E3E3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.black.withOpacity(0.35),
      ),
    );

    if (imageUrl == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl!,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E3E3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}
