import 'package:go_router/go_router.dart';

import '../../features/ocr/ocr_review_screen.dart';
import '../../features/trades/add_trade_method_screen.dart';
import '../../features/trades/add_trade_screen.dart';
import '../../features/trades/domain/trade.dart';
import '../../features/trades/trade_detail_screen.dart';

/// Add Trade routes (ARCHITECTURE.md §8 route tree, P0-08.01).
/// Top-level: leaving the shell puts the form in focus mode.
final addTradeRoutes = <GoRoute>[
  GoRoute(
    path: '/add-trade',
    builder: (context, state) => const AddTradeMethodScreen(),
  ),
  GoRoute(
    path: '/add-trade/manual',
    builder: (context, state) {
      // Edit flow (P0-10.05): the detail screen passes the full trade
      // as extra. OCR review (P1-05.02) passes the extracted draft —
      // same form, pre-filled, inputMethod = ocr. Null extra = fresh
      // manual entry.
      final extra = state.extra;
      if (extra is Trade) {
        return AddTradeScreen(
          initialDraft: extra.toDraft(),
          editing: extra,
        );
      }
      return AddTradeScreen(
        initialDraft: extra is TradeDraft ? extra : null,
      );
    },
  ),
  GoRoute(
    // P1-03: on-device OCR over the cropped temp file. The temp
    // image is released on every exit path (success/no-text/failure).
    path: '/add-trade/ocr-review',
    builder: (context, state) {
      final path = state.extra is String ? state.extra! as String : null;
      return OcrReviewScreen(tempPath: path);
    },
  ),
  GoRoute(
    path: '/trade/:id',
    builder: (context, state) =>
        TradeDetailScreen(tradeId: state.pathParameters['id']!),
  ),
];
