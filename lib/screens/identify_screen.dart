import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'home_after_auth_screen.dart';
import '../widgets/session_scope.dart';
import 'qr_camera_screen.dart';

class AuthScreen extends StatefulWidget {
  static const routeName = '/identify';

  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _passwordCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();

  bool _submitting = false;

  int _adminTapCount = 0;
  DateTime? _lastAdminTapAt;

  static const orange = Color(0xFFF36C21);
  static const lightGrey = Color(0xFFF3F3F3);
  static const cardGrey = Color(0xFFF6F6F6);

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _clientCtrl.dispose();
    _keywordCtrl.dispose();
    _qrCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onAdminSecretTap() {
    final now = DateTime.now();

    if (_lastAdminTapAt == null ||
        now.difference(_lastAdminTapAt!) > const Duration(seconds: 2)) {
      _adminTapCount = 0;
    }

    _lastAdminTapAt = now;
    _adminTapCount++;

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _openAdminSheet();
    }
  }

  void _openAdminSheet() {
    final session = SessionScope.of(context).session;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Menu admin",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: const Text("Réinitialiser le mot de passe admin"),
                    onPressed: _submitting
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await session.resetPassword();
                            _passwordCtrl.clear();
                            if (mounted) {
                              _snack("Mot de passe admin réinitialisé");
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Fermer"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, HomeAfterAuthScreen.routeName);
  }

  Future<void> _scanWithCamera() async {
    if (_submitting) return;

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrCameraScreen()),
    );

    if (raw == null) return;
    await _handleQr(raw);
  }

  /// QR JSON attendu:
  /// { "ctNum": "I51357", "doPiece": "PM204515" }
  /// Si doPiece est présent -> search keywords + pré-sélection.
  Future<void> _handleQr(String raw) async {
    final scope = SessionScope.of(context);
    final orders = scope.orders;

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _snack("QR vide");
      return;
    }

    setState(() => _submitting = true);
    try {
      final decoded = jsonDecode(trimmed);

      if (decoded is! Map) {
        throw Exception("QR invalide: pas un objet JSON");
      }

      final m = decoded.cast<String, dynamic>();

      final doPiece = m['doPiece']?.toString().trim();
      final ctNum = m['ctNum']?.toString().trim();

      if (doPiece != null && doPiece.isNotEmpty) {
        await orders.loadByKeyword(doPiece);
        if (orders.orders.isEmpty) {
          _snack("Commande introuvable: $doPiece");
          return;
        }

        orders.selectedPieces
          ..clear()
          ..add(orders.orders.first.doPiece);

        await _goHome();
        return;
      }

      if (ctNum != null && ctNum.isNotEmpty) {
        await orders.loadByClient(ctNum);
        if (orders.orders.isEmpty) {
          _snack("Aucune commande trouvée pour: $ctNum");
          return;
        }
        await _goHome();
        return;
      }

      _snack("QR invalide: clés attendues ctNum / doPiece");
    } catch (e) {
      _snack("Erreur QR: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _searchByClient(String doTiers) async {
    final orders = SessionScope.of(context).orders;

    final v = doTiers.trim();
    if (v.isEmpty) {
      _snack("Numéro client vide");
      return;
    }

    setState(() => _submitting = true);
    try {
      await orders.loadByClient(v);
      if (orders.orders.isEmpty) {
        _snack("Aucune commande trouvée pour: $v");
        return;
      }
      await _goHome();
    } catch (e) {
      _snack("Erreur: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _searchByKeyword(String keyword) async {
    final orders = SessionScope.of(context).orders;
    final v = keyword.trim();
    if (v.isEmpty) {
      _snack("Numéro de commande vide");
      return;
    }

    setState(() => _submitting = true);
    try {
      await orders.loadByKeyword(v);
      if (orders.orders.isEmpty) {
        _snack("Commande introuvable: $v");
        return;
      }

      orders.selectedPieces
        ..clear()
        ..add(orders.orders.first.doPiece);

      await _goHome();
    } catch (e) {
      _snack("Erreur: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitAdminPassword() async {
    final session = SessionScope.of(context).session;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await session.setPasswordAndLogin(_passwordCtrl.text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final contentMaxWidth = size.width >= 600 ? 520.0 : size.width * 0.92;

    final scope = SessionScope.of(context);
    final session = scope.session;

    // 1) Chargement global (init session)
    if (session.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) Mot de passe admin requis
    if (session.needsPassword) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      "INITIALISATION",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: orange,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Entrez le mot de passe admin (stocké localement).",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.45),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _OutlinedCard(
                      borderColor: orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Mot de passe admin",
                            style: TextStyle(
                              color: orange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: "••••••••",
                              filled: true,
                              fillColor: lightGrey,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _submitAdminPassword(),
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: _submitting ? "Validation..." : "Valider",
                            onTap: _submitting ? () {} : _submitAdminPassword,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    await session.resetPassword();
                                    _passwordCtrl.clear();
                                    _snack("Mot de passe réinitialisé");
                                  },
                            child: const Text("Réinitialiser le mot de passe"),
                          ),
                          if (session.error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              session.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 3) Identification client (UI front + logique back)
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 3),

                    // Title (tap secret admin)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onAdminSecretTap, // 👈 5 taps rapides
                      child: const Text(
                        "IDENTIFIEZ VOUS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: orange,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Choisir une méthode d'identification",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.45),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 59),

                    // Card 1: Scan QR (caméra)
                    _InkCard(
                      onTap: _scanWithCamera,
                      child: _SoftCard(
                        background: cardGrey,
                        borderColor: Colors.transparent,
                        child: Row(
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.08),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.qr_code_2,
                                  size: 86,
                                  color: Colors.black.withOpacity(0.75),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Scanner mon\nQR code",
                                    style: TextStyle(
                                      color: orange,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Scanner le QR code sur le\nsite web",
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.45),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _submitting
                                        ? "Traitement..."
                                        : "Touchez pour scanner",
                                    style: TextStyle(
                                      color: orange.withOpacity(0.9),
                                      fontSize: 12.5,
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

                    const SizedBox(height: 18),

                    // Card 2: Client number
                    _OutlinedCard(
                      borderColor: orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.person,
                                  color: Colors.black87, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Entrer mon numéro\nclient",
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _RoundedField(
                            controller: _clientCtrl,
                            hint: "I51357",
                            fill: lightGrey,
                            onSubmitted: (_) =>
                                _searchByClient(_clientCtrl.text),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                return newValue.copyWith(
                                    text: newValue.text.toUpperCase());
                              }),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: _submitting ? "Chargement..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _searchByClient(_clientCtrl.text),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Card 3: Order number
                    _OutlinedCard(
                      borderColor: orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.receipt_long,
                                  color: Colors.black87, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Entrer mon numéro\nde commande",
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _RoundedField(
                            controller: _keywordCtrl,
                            hint: "PM204515",
                            fill: lightGrey,
                            onSubmitted: (_) =>
                                _searchByKeyword(_keywordCtrl.text),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                return newValue.copyWith(
                                    text: newValue.text.toUpperCase());
                              }),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: _submitting ? "Chargement..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _searchByKeyword(_keywordCtrl.text),
                          ),
                        ],
                      ),
                    ),

                    // Optionnel: debug "coller QR JSON" (caché en bas)
                    // const SizedBox(height: 18),
                    // ExpansionTile(
                    //   tilePadding: EdgeInsets.zero,
                    //   title: Text(
                    //     "Option avancée: coller un QR (JSON)",
                    //     style: TextStyle(
                    //       color: Colors.black.withOpacity(0.55),
                    //       fontWeight: FontWeight.w700,
                    //       fontSize: 13,
                    //     ),
                    //   ),
                    //   children: [
                    //     const SizedBox(height: 8),
                    //     TextField(
                    //       controller: _qrCtrl,
                    //       decoration: InputDecoration(
                    //         hintText: '{"ctNum":"I51357","doPiece":"PM204515"}',
                    //         filled: true,
                    //         fillColor: lightGrey,
                    //         border: OutlineInputBorder(
                    //           borderRadius: BorderRadius.circular(14),
                    //           borderSide: BorderSide.none,
                    //         ),
                    //       ),
                    //       minLines: 1,
                    //       maxLines: 4,
                    //     ),
                    //     const SizedBox(height: 10),
                    //     _PrimaryButton(
                    //       label: _submitting
                    //           ? "Traitement..."
                    //           : "Valider le texte",
                    //       onTap: _submitting
                    //           ? () {}
                    //           : () => _handleQr(_qrCtrl.text),
                    //     ),
                    //     const SizedBox(height: 6),
                    //   ],
                    // ),

                    if (_submitting) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- UI components (repris du front) ---------------- */

class _SoftCard extends StatelessWidget {
  final Widget child;
  final Color background;
  final Color borderColor;

  const _SoftCard({
    required this.child,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _OutlinedCard({
    required this.child,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: child,
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color fill;
  final ValueChanged<String> onSubmitted;
  final List<TextInputFormatter>? inputFormatters; // 👈 AJOUT

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.fill,
    required this.onSubmitted,
    this.inputFormatters, // 👈 AJOUT
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      inputFormatters: inputFormatters, // 👈 AJOUT
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _InkCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InkCard({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}
