class OrderResponse {
  final int totalItems;
  final List<OrderHeader> orders;

  OrderResponse({required this.totalItems, required this.orders});

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['fDocentetes'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderHeader.fromJson(e.cast<String, dynamic>()))
        .toList();

    return OrderResponse(
      totalItems: (json['totalItems'] as num?)?.toInt() ?? list.length,
      orders: list,
    );
  }
}

class OrderHeader {
  final String doPiece; // "PM204515"
  final String doRef; // 👈 AJOUT (peut être vide)
  final DateTime? doDate;
  final String doStatutString; // "A livrer"
  final String ctNum; // doTiers.ctNum
  final String doTotalttc;

  final String? doCoord01;

  final List<OrderLine> lines;

  OrderHeader({
    required this.doPiece,
    required this.doRef,
    required this.doDate,
    required this.doStatutString,
    required this.ctNum,
    required this.doTotalttc,
    required this.lines,
    this.doCoord01,
  });

  /// Affichage prioritaire: doRef, sinon doPiece
  String get displayOrderId {
    final ref = doRef.trim();
    if (ref.isNotEmpty) return ref;
    return doPiece.trim();
  }

  factory OrderHeader.fromJson(Map<String, dynamic> json) {
    final doTiers =
        (json['doTiers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final linesJson = (json['fDoclignesPaginate'] as List? ?? []);

    return OrderHeader(
      doPiece: (json['doPiece'] ?? '').toString(),
      doRef: (json['doRef'] ?? '').toString(),
      doDate: _tryParseDate(json['doDate']?.toString()),
      doStatutString: (json['doStatutString'] ?? '').toString(),
      ctNum: (doTiers['ctNum'] ?? '').toString(),
      doTotalttc: (json['doTotalttc'] ?? '').toString(),
      doCoord01: json['doCoord01']?.toString(),
      lines: linesJson
          .whereType<Map>()
          .map((e) => OrderLine.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class OrderLine {
  final String arRef;
  final String dlDesign;
  final String dlQte;
  final String dlPrixunitaire;
  final List<OrderImage> images;

  OrderLine({
    required this.arRef,
    required this.dlDesign,
    required this.dlQte,
    required this.dlPrixunitaire,
    required this.images,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final imgs = (json['images'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderImage.fromJson(e.cast<String, dynamic>()))
        .toList();

    return OrderLine(
      arRef: (json['arRef'] ?? '').toString(),
      dlDesign: (json['dlDesign'] ?? '').toString(),
      dlQte: (json['dlQte'] ?? '').toString(),
      dlPrixunitaire: (json['dlPrixunitaire'] ?? '').toString(),
      images: imgs,
    );
  }
}

class OrderImage {
  final String name;
  final List<int> sizes;
  final int sort;

  OrderImage({required this.name, required this.sizes, required this.sort});

  factory OrderImage.fromJson(Map<String, dynamic> json) {
    return OrderImage(
      name: (json['name'] ?? '').toString(),
      sizes: (json['sizes'] as List? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList(),
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _tryParseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}
