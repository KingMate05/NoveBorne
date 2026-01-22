import 'package:json_annotation/json_annotation.dart';

part 'farticle_emplacement_history.g.dart';

@JsonSerializable()
class FArticleEmplacementHistory {
  String arRef;
  String arDesign;
  String? images;
  String constructeurRef;
  String? arCodebarre;
  int asQtesto;
  int asQteprepa;
  int asQteres;
  int asQtecom;

  FArticleEmplacementHistory({
    required this.arRef,
    required this.arDesign,
    required this.images,
    required this.constructeurRef,
    required this.arCodebarre,
    required this.asQtesto,
    required this.asQteprepa,
    required this.asQteres,
    required this.asQtecom,
  });

  factory FArticleEmplacementHistory.fromJson(Map<String, dynamic> json) =>
      _$FArticleEmplacementHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$FArticleEmplacementHistoryToJson(this);
}
