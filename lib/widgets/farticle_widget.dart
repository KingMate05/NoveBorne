import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nove_console_article/class/emplacement.dart';
import 'package:nove_console_article/class/farticle.dart';
import 'package:nove_console_article/widgets/farticle_emplacement_history_widget.dart';
import 'package:nove_console_article/widgets/new_emplacement_widget.dart';
import 'package:nove_console_article/widgets/scan_reader.dart';

class FArticleWidget extends HookWidget {
  final FArticle fArticle;
  final void Function(String value, [bool force]) onScan;
  final void Function(String value, [bool force]) onScanSurStock;
  final Emplacement? newEmplacement;
  final Emplacement? newEmplacementSurStock;
  final void Function(String? value) changeEmplacement;
  final void Function(String? value) changeEmplacementSurStock;

  const FArticleWidget(
      {super.key,
      required this.fArticle,
      required this.onScan,
      required this.newEmplacement,
      required this.newEmplacementSurStock,
      required this.changeEmplacement,
      required this.changeEmplacementSurStock,
      required this.onScanSurStock});

  @override
  Widget build(BuildContext context) {
    var table2 = useState<List<String>>(
        ["Réel", "Préparé (PL)", "Réservé (BL)", "Commandé"]);
    var loading = useState<bool>(false);
    GlobalKey<dynamic> scanKey = GlobalKey();
    GlobalKey<dynamic> scanSurStockKey = GlobalKey();
    var activeScan = useState<int>(0);

    void onChangeEmplacement(String? value) {
      if (value != null) {
        loading.value = true;
      }
      changeEmplacement(value);
    }

    void onChangeEmplacementSurStock(String? value) {
      if (value != null) {
        loading.value = true;
      }
      changeEmplacementSurStock(value);
    }

    void changeActive(int value) {
      activeScan.value = value;
    }

    onRefresh() async {
      var search = fArticle.arCodebarre ?? '';
      if (search == '') {
        search = fArticle.constructeurRef;
      }
      if (search == '') {
        search = fArticle.arRef;
      }
      onScan(search, true);
    }

    useEffect(() {
      loading.value = false;
      if (scanKey.currentState != null) {
        scanKey.currentState.closeEdit();
      }
      if (scanSurStockKey.currentState != null) {
        scanSurStockKey.currentState.closeEdit();
      }
      return null;
    }, [fArticle.dpCode, fArticle.surstock]);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                child: fArticle.images == null
                    ? const SizedBox.shrink()
                    : Image.network(
                        'https://api.nove.fr/DATA/fArticle/images/${fArticle.arRef}/sizes/${fArticle.images}',
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                          return const Text('Image could not be loaded');
                        },
                      ),
              ),
              if (newEmplacement != null) ...[
                NewEmplacementWidget(
                    fArticle: fArticle,
                    newEmplacement: newEmplacement,
                    surStock: false,
                    onChangeEmplacement: onChangeEmplacement),
              ],
              if (loading.value == true) ...[const CircularProgressIndicator()],
              ScanReader(
                onScan: onScan,
                key: scanKey,
                index: 0,
                activeScan: activeScan,
                changeActive: changeActive,
                scanIdentifier:
                    'productScan-${fArticle.arRef}-${fArticle.dpCode}',
                widget: Text(fArticle.dpCode ?? "Pas d'emplacement",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              Table(
                border: TableBorder.all(),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: <TableRow>[
                  TableRow(
                    children: <Widget>[
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.arRef,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                          ),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.constructeurRef,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple)),
                          ),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.arCodebarre ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (newEmplacementSurStock != null) ...[
                NewEmplacementWidget(
                    fArticle: fArticle,
                    newEmplacement: newEmplacementSurStock,
                    surStock: true,
                    onChangeEmplacement: onChangeEmplacementSurStock),
              ],
              if (loading.value == true) ...[const CircularProgressIndicator()],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Surstock"),
                  ScanReader(
                    onScan: onScanSurStock,
                    key: scanSurStockKey,
                    index: 1,
                    activeScan: activeScan,
                    scanIdentifier:
                        'productScanSurStock-${fArticle.arRef}-${fArticle.dpCode}',
                    changeActive: changeActive,
                    widget: Text(fArticle.surstock ?? "",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                ],
              ),
              Row(
                children: [
                  Flexible(child: Text(fArticle.arDesign)),
                  Center(
                    child: fArticle.driverImage != null
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 50,
                            ),
                            child: Image.network(
                                'https://api.nove.fr/DATA/constructor/${fArticle.driverImage}',
                                errorBuilder: (BuildContext context,
                                    Object exception, StackTrace? stackTrace) {
                              return const Text('Image could not be loaded');
                            }),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              Table(
                border: TableBorder.all(),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: <TableRow>[
                  TableRow(
                    children: table2.value
                        .map((entry) => TableCell(
                              verticalAlignment: TableCellVerticalAlignment.top,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 10, right: 10),
                                child: Center(
                                  child: Text(entry),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  TableRow(
                    children: [
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.asQtesto.toString()),
                          ),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.asQteprepa.toString()),
                          ),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.asQteres.toString()),
                          ),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.top,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Center(
                            child: Text(fArticle.asQtecom.toString()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (fArticle.emplacementHistories.isNotEmpty)
                ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  reverse: true,
                  itemCount: fArticle.emplacementHistories.length,
                  prototypeItem: FArticleEmplacementHistoriesWidget(
                      emplacementHistoryFArticle:
                          fArticle.emplacementHistories.first),
                  itemBuilder: (context, index) {
                    return FArticleEmplacementHistoriesWidget(
                        emplacementHistoryFArticle:
                            fArticle.emplacementHistories[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
