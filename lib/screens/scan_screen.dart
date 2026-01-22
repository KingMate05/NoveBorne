import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:nove_console_article/class/emplacement.dart';
import 'package:nove_console_article/class/emplacement_history.dart';
import 'package:nove_console_article/screens/emplacement_screen.dart';
import 'package:nove_console_article/screens/product_screen.dart';
import 'package:nove_console_article/widgets/emplacement_history_farticle_widget.dart';
import 'package:nove_console_article/widgets/scan_reader.dart';

class ScanScreen extends HookWidget {
  final List<Emplacement> emplacements;
  final String token;

  const ScanScreen(
      {super.key, required this.emplacements, required this.token});

  @override
  Widget build(BuildContext context) {
    var page = useState<int>(1);
    var totalItems = useState<int>(0);
    var loading = useState<bool>(true);
    var emplacementHistories = useState<List<EmplacementHistory>>([]);

    void onScan(String value, [bool force = false]) {
      value = value.toUpperCase();
      if (emplacements.map((e) => e.dpCode).contains(value)) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => EmplacementScreen(
                  identifier: value,
                  emplacements: emplacements,
                  token: token,
                )));
      } else {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProductScreen(
                  initIdentifier: value,
                  token: token,
                  emplacements: emplacements,
                )));
      }
    }

    load() async {
      var response = await http.get(
          Uri.https('api.nove.fr', '/api/f_article_emplacement_histories', {
            'page': page.value.toString(),
            'itemsPerPage': '20',
          }),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token'
          });
      if (response.statusCode == 200) {
        dynamic body = jsonDecode(response.body);
        List<EmplacementHistory> newEmplacementHistories = [];
        if (page.value > 1) {
          newEmplacementHistories = emplacementHistories.value;
        }
        totalItems.value = body['totalItems'];
        for (var e in body['fArticleEmplacementHistories']) {
          newEmplacementHistories.add(EmplacementHistory.fromJson(e));
        }
        emplacementHistories.value = newEmplacementHistories;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Une erreur est survenue"),
          ));
        }
      }
      loading.value = false;
    }

    Future<void> onRefresh([int thisPage = 1]) async {
      if (loading.value ||
          (thisPage > 1 &&
              emplacementHistories.value.length >= totalItems.value)) {
        return;
      }
      page.value = thisPage;
      if (thisPage == 1) {
        emplacementHistories.value = [];
      }
      loading.value = true;
    }

    useEffect(() {
      if (loading.value) {
        load();
      }
      return null;
    }, [loading.value]);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: onRefresh,
        child: const Icon(Icons.refresh),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
            child: ScanReader(onScan: onScan, scanIdentifier: 'mainScan'),
          ),
          if (emplacementHistories.value.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                child: NotificationListener(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: emplacementHistories.value.length,
                    itemBuilder: (context, index) {
                      return EmplacementHistoryFArticlesWidget(
                          emplacementHistory: emplacementHistories.value[index],
                          onScan: onScan);
                    },
                  ),
                  onNotification: (ScrollEndNotification scrollEnd) {
                    final metrics = scrollEnd.metrics;
                    if (metrics.atEdge) {
                      bool isBottom = metrics.pixels != 0;
                      if (isBottom) {
                        onRefresh(page.value + 1);
                      }
                    }
                    return true;
                  },
                ),
              ),
            ),
          if (loading.value) const CircularProgressIndicator()
        ],
      ),
    );
  }
}
