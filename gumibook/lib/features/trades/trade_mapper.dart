import 'package:appwrite/models.dart' as models;

import 'domain/trade.dart';

/// Appwrite document ↔ domain mapping (P0-07.05, DATABASE.md §4, §10).
///
/// Datetimes serialize as UTC ISO 8601 (`Z` suffix) — Appwrite reads
/// naive strings as UTC, so an explicit UTC round-trip keeps wall
/// times stable across timezones/DST. Unknown/invalid enum strings
/// never throw — they become null and surface as data review flags.
/// ponytail: collection IDs live in AppwriteConfig; repositories own
/// them, the mapper stays pure mapping only.
abstract final class TradeMapper {

  static Map<String, dynamic> toDocument(Trade t) => {
        'userId': t.userId,
        'instrument': t.instrument,
        'direction': t.direction.name,
        'accountType': t.accountType.name,
        'entryPrice': t.entryPrice,
        'exitPrice': t.exitPrice,
        'stopLoss': t.stopLoss,
        'takeProfit': t.takeProfit,
        'lotSize': t.lotSize,
        'profitLoss': t.profitLoss,
        'riskReward': t.riskReward,
        'openTime': t.openTime.toUtc().toIso8601String(),
        'closeTime': t.closeTime.toUtc().toIso8601String(),
        'strategy': t.strategy,
        'session': t.session,
        'confluence': t.confluence,
        'emotion': t.emotion,
        'mistakeTags': t.mistakeTags,
        'lessonLearned': t.lessonLearned,
        'notes': t.notes,
        'inputMethod': t.inputMethod.name,
      }..removeWhere((_, v) => v == null); // optional fields stay omittable

  static Trade fromDocument(models.Document doc) {
    final d = doc.data;
    return Trade(
      id: doc.$id,
      userId: d['userId'] as String? ?? '',
      instrument: d['instrument'] as String? ?? '',
      direction:
          directionFromString(d['direction'] as String?) ?? TradeDirection.buy,
      accountType: accountTypeFromString(d['accountType'] as String?) ??
          TradeAccountType.real,
      entryPrice: (d['entryPrice'] as num?)?.toDouble() ?? 0,
      exitPrice: (d['exitPrice'] as num?)?.toDouble() ?? 0,
      stopLoss: (d['stopLoss'] as num?)?.toDouble(),
      takeProfit: (d['takeProfit'] as num?)?.toDouble(),
      lotSize: (d['lotSize'] as num?)?.toDouble() ?? 0,
      profitLoss: (d['profitLoss'] as num?)?.toDouble() ?? 0,
      riskReward: (d['riskReward'] as num?)?.toDouble(),
      openTime: DateTime.tryParse(d['openTime'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      closeTime:
          DateTime.tryParse(d['closeTime'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      strategy: d['strategy'] as String?,
      session: d['session'] as String?,
      confluence: (d['confluence'] as List?)?.cast<String>() ?? const [],
      emotion: d['emotion'] as String?,
      mistakeTags: (d['mistakeTags'] as List?)?.cast<String>() ?? const [],
      lessonLearned: d['lessonLearned'] as String?,
      notes: d['notes'] as String?,
      inputMethod: inputMethodFromString(d['inputMethod'] as String?) ??
          TradeInputMethod.manual,
      createdAt: DateTime.tryParse(doc.$createdAt),
      updatedAt: DateTime.tryParse(doc.$updatedAt),
    );
  }
}
