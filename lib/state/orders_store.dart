import '../models/order.dart';
import '../services/orders_service.dart';
import 'package:flutter/foundation.dart';

class OrdersStore extends ChangeNotifier {
  final OrdersService ordersService;

  OrdersStore({required this.ordersService});

  bool isLoading = false;
  String? error;
  List<OrderHeader> orders = [];
  final Set<String> selectedPieces = {};

  void clear() {
    orders = [];
    selectedPieces.clear();
    error = null;
    notifyListeners();
  }

  void toggleSelected(String doPiece) {
    if (selectedPieces.contains(doPiece)) {
      selectedPieces.remove(doPiece);
    } else {
      selectedPieces.add(doPiece);
    }
    notifyListeners();
  }

  List<OrderHeader> get selectedOrders =>
      orders.where((o) => selectedPieces.contains(o.doPiece)).toList();

  Future<void> loadByClient(String doTiers) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await ordersService.getOrdersByClient(doTiers: doTiers);
      orders = res.orders;
      selectedPieces.clear();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadByKeyword(String keyword) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final v = keyword.trim();
    if (v.isEmpty) {
      isLoading = false;
      error = "Numéro de commande vide";
      notifyListeners();
      return;
    }

    // Empêche la recherche trop large ("P", "A", etc.)
    if (v.length < 5) {
      isLoading = false;
      error = "Entrez au moins 5 caractères";
      notifyListeners();
      return;
    }

    try {
      final res = await ordersService.searchOrders(keyword: v);

      // Filtre EXACT sur doPiece
      final exact = res.orders.where((o) {
        final doPiece = (o.doPiece ?? '').toString().trim();
        return doPiece.toUpperCase() == v.toUpperCase();
      }).toList();

      orders = exact;
      selectedPieces.clear();

      if (orders.isEmpty) {
        error = "Commande introuvable: $v";
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
