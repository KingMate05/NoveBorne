// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farticle_emplacement_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FArticleEmplacementHistory _$FArticleEmplacementHistoryFromJson(
        Map<String, dynamic> json) =>
    FArticleEmplacementHistory(
      arRef: json['arRef'] as String,
      arDesign: json['arDesign'] as String,
      images: json['images'] as String?,
      constructeurRef: json['constructeurRef'] as String,
      arCodebarre: json['arCodebarre'] as String?,
      asQtesto: json['asQtesto'] as int,
      asQteprepa: json['asQteprepa'] as int,
      asQteres: json['asQteres'] as int,
      asQtecom: json['asQtecom'] as int,
    );

Map<String, dynamic> _$FArticleEmplacementHistoryToJson(
        FArticleEmplacementHistory instance) =>
    <String, dynamic>{
      'arRef': instance.arRef,
      'arDesign': instance.arDesign,
      'images': instance.images,
      'constructeurRef': instance.constructeurRef,
      'arCodebarre': instance.arCodebarre,
      'asQtesto': instance.asQtesto,
      'asQteprepa': instance.asQteprepa,
      'asQteres': instance.asQteres,
      'asQtecom': instance.asQtecom,
    };
