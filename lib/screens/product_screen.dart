import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:nove_console_article/class/emplacement.dart';
import 'package:nove_console_article/class/farticle.dart';
import 'package:nove_console_article/widgets/farticle_widget.dart';
import 'package:nove_console_article/widgets/farticles_widget.dart';
import 'package:nove_console_article/widgets/scan_reader.dart';

class ProductScreen extends HookWidget {
  final String initIdentifier;
  final String token;
  final List<Emplacement> emplacements;

  const ProductScreen(
      {super.key,
      required this.initIdentifier,
      required this.token,
      required this.emplacements});

  @override
  Widget build(BuildContext context) {
    var fArticles = useState<List<FArticle>?>(null);
    var identifier = useState<String>(initIdentifier);
    var newEmplacement = useState<Emplacement?>(null);
    var newEmplacementSurStock = useState<Emplacement?>(null);

    void changeNewEmplacement(String value,
        ValueNotifier<Emplacement?> newEmplacementNotifier, bool surStock,
        [bool force = false]) {
      value = value.toUpperCase();
      var thisNewEmplacement = emplacements.where((e) => e.dpCode == value);
      if (thisNewEmplacement.isNotEmpty) {
        if ((!surStock && value == fArticles.value![0].dpCode) ||
            (surStock && value == fArticles.value![0].surstock)) {
          return;
        }
        newEmplacementNotifier.value = thisNewEmplacement.first;
      } else {
        var isCurrentArticle = fArticles.value != null &&
            fArticles.value!.length == 1 &&
            (fArticles.value![0].arRef == value ||
                fArticles.value![0].constructeurRef == value ||
                // region barcode
                fArticles.value![0].arCodebarre == value ||
                fArticles.value![0].arCodebarre == "0$value" ||
                "0${fArticles.value![0].arCodebarre}" == value ||
                fArticles.value![0].arCodebarre == "${value}0" ||
                "${fArticles.value![0].arCodebarre}0" == value
            // endregion
            );
        if (!isCurrentArticle || force) {
          newEmplacementNotifier.value = null;
          fArticles.value = null;
          identifier.value = value;
        }
      }
    }

    void onScanSurStock(String value, [bool force = false]) {
      changeNewEmplacement(value, newEmplacementSurStock, true, force);
    }

    void onScan(String value, [bool force = false]) {
      changeNewEmplacement(value, newEmplacement, false, force);
    }

    void requestChangeEmplacement(String? value, bool surStock,
        ValueNotifier<Emplacement?> newEmplacementNotifier) async {
      if (!surStock &&
          (value == null || fArticles.value![0].fArtstockCbMarq == null)) {
        newEmplacementNotifier.value = null;
        return;
      }
      http.Response? response;
      if (surStock) {
        final map = <String, dynamic>{};
        map['json'] = jsonEncode(<String, String>{
          'arRef': fArticles.value![0].arRef,
          'surstock': value ?? '',
        });
        response = await http.post(
            Uri.https('api.nove.fr', '/api/f_articles', {
              'console': '1',
            }),
            headers: <String, String>{'Authorization': 'Bearer $token'},
            body: map);
      } else {
        response = await http.patch(
            Uri.https('api.nove.fr',
                '/api/f_artstocks/${fArticles.value![0].fArtstockCbMarq!}', {
              'console': '1',
            }),
            headers: <String, String>{
              'Content-Type': 'application/merge-patch+json',
              'Authorization': 'Bearer $token'
            },
            body: jsonEncode(<String, int>{
              'dpNoprincipal': newEmplacementNotifier.value!.dpNo,
            }));
      }
      if (response.statusCode == 200) {
        dynamic body = jsonDecode(response.body);
        List<FArticle> newFArticles = [];
        for (var f in body) {
          newFArticles.add(FArticle.fromJson(f));
        }
        fArticles.value = newFArticles;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Une erreur est survenue"),
          ));
        }
      }
      newEmplacementNotifier.value = null;
    }

    void changeEmplacement(String? value) async {
      requestChangeEmplacement(value, false, newEmplacement);
    }

    void changeEmplacementSurStock(String? value) async {
      requestChangeEmplacement(value, true, newEmplacementSurStock);
    }

    load() async {
      var response = await http.get(
          Uri.https('api.nove.fr', '/api/console-article/f_artstocks', {
            'search': identifier.value,
          }),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token'
          });
      if (response.statusCode == 200) {
        dynamic body = jsonDecode(response.body);
        List<FArticle> newFArticles = [];
        for (var f in body) {
          newFArticles.add(FArticle.fromJson(f));
        }
        fArticles.value = newFArticles;
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Une erreur est survenue"),
          ));
        }
      }
      return false;
    }

    useEffect(() {
      if (fArticles.value == null) {
        load();
      }
      return null;
    }, [identifier.value, fArticles.value]);

    return SafeArea(
      child: Scaffold(
        body: fArticles.value == null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text("Chargement de l'article ${identifier.value}"),
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  ],
                ),
              )
            : fArticles.value!.length == 1
                ? FArticleWidget(
                    fArticle: fArticles.value![0],
                    onScan: onScan,
                    onScanSurStock: onScanSurStock,
                    newEmplacement: newEmplacement.value,
                    newEmplacementSurStock: newEmplacementSurStock.value,
                    changeEmplacement: changeEmplacement,
                    changeEmplacementSurStock: changeEmplacementSurStock)
                : fArticles.value!.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            const Text("Aucun article trouvé"),
                            ScanReader(
                                onScan: onScan,
                                scanIdentifier: 'productScanNotFound')
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(fArticles.value![0].arRef),
                            ScanReader(
                                onScan: onScan,
                                scanIdentifier: 'multipleProducts'),
                            Expanded(
                              child: FArticlesWidget(
                                  fArticles: fArticles.value!, onScan: onScan),
                            )
                          ],
                        ),
                      ),
      ),
    );
  }
}
