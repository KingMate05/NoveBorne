// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emplacement_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmplacementHistory _$EmplacementHistoryFromJson(Map<String, dynamic> json) =>
    EmplacementHistory(
      id: json['id'] as int,
      o: json['o'] as String?,
      n: json['n'] as String,
      c: json['c'] as String,
      fArticleId: json['fArticleId'] as String,
      fArticle: FArticleEmplacementHistory.fromJson(
          json['fArticle'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$EmplacementHistoryToJson(EmplacementHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'o': instance.o,
      'n': instance.n,
      'c': instance.c,
      'fArticleId': instance.fArticleId,
      'fArticle': instance.fArticle,
    };
