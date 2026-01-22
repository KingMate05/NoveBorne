import 'package:json_annotation/json_annotation.dart';

part 'emplacement_history_farticle.g.dart';

@JsonSerializable()
class EmplacementHistoryFArticle {
  String o; // old emplacement
  String n; // new emplacement
  String c; // date of change

  EmplacementHistoryFArticle({
    required this.o,
    required this.n,
    required this.c,
  });

  factory EmplacementHistoryFArticle.fromJson(Map<String, dynamic> json) =>
      _$EmplacementHistoryFArticleFromJson(json);

  Map<String, dynamic> toJson() => _$EmplacementHistoryFArticleToJson(this);
}
