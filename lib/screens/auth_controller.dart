import 'dart:convert';
import 'package:flutter/material.dart';

import '../widgets/session_scope.dart';

class AuthController {
  AuthController({
    required this.getContext,
    required this.snack,
    required this.goHome,
    required this.setSubmitting,
  });

  final BuildContext Function() getContext;
  final void Function(String msg) snack;
  final Future<void> Function() goHome;
  final void Function(bool v) setSubmitting;

  // ----------------- Public API -----------------

  Future<void> submitAdminPassword(String password) async {
    final ctx = getContext();
    final session = SessionScope.of(ctx).session;

    setSubmitting(true);
    try {
      await session.setPasswordAndLogin(password);
    } catch (e) {
      snack("Erreur: $e");
    } finally {
      setSubmitting(false);
    }
  }

  Future<void> searchByClient(String doTiers) async {
    final ctx = getContext();
    final orders = SessionScope.of(ctx).orders;

    final v = doTiers.trim();
    if (v.isEmpty) {
      snack("Numéro client vide");
      return;
    }

    setSubmitting(true);
    try {
      await orders.loadByClient(v);
      if (orders.orders.isEmpty) {
        snack("Aucune commande trouvée pour: $v");
        return;
      }
      await goHome();
    } catch (e) {
      snack("Erreur: $e");
    } finally {
      setSubmitting(false);
    }
  }

  Future<void> searchByKeyword(String keyword) async {
    final ctx = getContext();
    final orders = SessionScope.of(ctx).orders;

    final v = keyword.trim();
    if (v.isEmpty) {
      snack("Numéro de commande vide");
      return;
    }

    setSubmitting(true);
    try {
      await orders.loadByKeyword(v);
      if (orders.orders.isEmpty) {
        snack("Commande introuvable: $v");
        return;
      }

      orders.selectedPieces
        ..clear()
        ..add(orders.orders.first.doPiece);

      await goHome();
    } catch (e) {
      snack("Erreur: $e");
    } finally {
      setSubmitting(false);
    }
  }

  /// QR JSON attendu:
  /// { "ctNum": "I51357", "doPiece": "PM204515" }
  /// - si doPiece -> recherche par keyword + preselect
  /// - sinon si ctNum/client -> recherche par client
  Future<void> handleQr(String raw) async {
    final ctx = getContext();
    final scope = SessionScope.of(ctx);

    final orders = scope.orders;

    final extracted = _extractCompleteJson(raw) ?? raw;
    final trimmed = extracted.trim();

    if (trimmed.isEmpty) {
      snack("QR vide");
      return;
    }

    setSubmitting(true);
    try {
      final decoded = jsonDecode(trimmed);

      if (decoded is! Map) {
        throw Exception("QR invalide: pas un objet JSON");
      }

      final m = decoded.cast<String, dynamic>();

      final doPiece = m['doPiece']?.toString().trim();
      final ctNumRaw = (m['ctNum'] ?? m['client'])?.toString() ?? "";
      final ctNum =
          ctNumRaw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

      // Priorité commande
      if (doPiece != null && doPiece.isNotEmpty) {
        await orders.loadByKeyword(doPiece);
        if (orders.orders.isEmpty) {
          snack("Commande introuvable: $doPiece");
          return;
        }

        orders.selectedPieces
          ..clear()
          ..add(orders.orders.first.doPiece);

        await goHome();
        return;
      }

      // Sinon client
      if (ctNum.isNotEmpty) {
        await orders.loadByClient(ctNum);
        if (orders.orders.isEmpty) {
          snack("Aucune commande trouvée pour: $ctNum");
          return;
        }
        await goHome();
        return;
      }

      snack("QR invalide: clés attendues ctNum / doPiece");
    } catch (e) {
      snack("Erreur QR: $e");
    } finally {
      setSubmitting(false);
    }
  }

  // ----------------- Utils -----------------

  /// Extrait le premier objet JSON complet trouvé dans une string.
  /// (copie de ta logique, utilisée pour rendre handleQr robuste)
  String? _extractCompleteJson(String input) {
    if (input.isEmpty) return null;

    // enlève les caractères de contrôle (sauf \n \r \t)
    final cleaned = input.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
      '',
    );

    final start = cleaned.indexOf('{');
    if (start == -1) return null;

    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = start; i < cleaned.length; i++) {
      final ch = cleaned[i];

      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      } else {
        if (ch == '"') {
          inString = true;
          continue;
        }
        if (ch == '{') depth++;
        if (ch == '}') depth--;

        if (depth == 0 && i > start) {
          return cleaned.substring(start, i + 1);
        }
      }
    }

    return null;
  }
}
