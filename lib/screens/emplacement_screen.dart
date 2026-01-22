import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:nove_console_article/class/emplacement.dart';
import 'package:nove_console_article/class/farticle.dart';
import 'package:nove_console_article/screens/product_screen.dart';
import 'package:nove_console_article/widgets/farticles_widget.dart';
import 'package:nove_console_article/widgets/scan_reader.dart';

class EmplacementScreen extends HookWidget {
  final String identifier;
  final List<Emplacement> emplacements;
  final String token;

  const EmplacementScreen(
      {super.key,
      required this.identifier,
      required this.emplacements,
      required this.token});

  @override
  Widget build(BuildContext context) {
    var identifiers = useState<List<String>>([identifier]);
    var loading = useState<bool>(true);
    var fArticles = useState<List<FArticle>>([]);

    void onScan(String value, [bool force = false]) {
      value = value.toUpperCase();
      var thisNewEmplacement = emplacements.where((e) => e.dpCode == value);
      if (thisNewEmplacement.isNotEmpty) {
        if (!identifiers.value.contains(value)) {
          var newIdentifiers = identifiers.value;
          newIdentifiers.add(value);
          identifiers.value = [...newIdentifiers];
        }
      } else {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProductScreen(
                  initIdentifier: value,
                  token: token,
                  emplacements: emplacements,
                )));
      }
    }

    Future<void> updateFArticles() async {
      var response = await http.get(
          Uri.https('api.nove.fr', '/api/console-article/f_artstocks', {
            'emplacements': jsonEncode(identifiers.value),
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
        newFArticles.sort((a, b) {
          if (a.asQtesto > 0 && b.asQtesto <= 0) {
            return -1;
          }
          if (a.asQtesto <= 0 && b.asQtesto > 0) {
            return 1;
          }
          return (a.dpCode ?? "").compareTo(b.dpCode ?? "");
        });
        fArticles.value = newFArticles;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Une erreur est survenue"),
          ));
        }
      }
      loading.value = false;
    }

    useEffect(() {
      if (!loading.value) {
        loading.value = true;
      }
      return null;
    }, [identifiers.value]);

    useEffect(() {
      if (loading.value) {
        updateFArticles();
      }
      return null;
    }, [loading.value]);

    return SafeArea(
      child: Scaffold(
        body: loading.value
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: <Widget>[
                  Padding(
                    padding:
                        const EdgeInsets.only(right: 8.0, left: 8.0, top: 8.0),
                    child: ScanReader(
                        onScan: onScan, scanIdentifier: 'emplacements'),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                      child: FArticlesWidget(
                          fArticles: fArticles.value, onScan: onScan),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}
