import 'package:flutter/foundation.dart';
import '../models/sftp_transfer_item.dart';

class SftpTransferProvider extends ChangeNotifier {
  List<SftpTransferItem> _items = [];
  bool _cancelled = false;

  List<SftpTransferItem> get items => List.unmodifiable(_items);
  bool get isCancelled => _cancelled;

  bool get isTransferring =>
      _items.any((i) => i.status == TransferStatus.inProgress);

  double get overallProgress {
    final total = _items.fold<int>(0, (s, i) => s + i.totalBytes);
    if (total == 0) return 0;
    return _items.fold<int>(0, (s, i) => s + i.bytesTransferred) / total;
  }

  int get completedCount => _items
      .where((i) => i.status == TransferStatus.done || i.status == TransferStatus.skipped)
      .length;

  int get totalCount => _items.length;

  void startBatch(List<SftpTransferItem> items) {
    _items = List.of(items);
    _cancelled = false;
    notifyListeners();
  }

  void updateItem(String id, {int? bytesTransferred, TransferStatus? status, String? errorMessage}) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = _items[idx];
    if (bytesTransferred != null) item.bytesTransferred = bytesTransferred;
    if (status != null) item.status = status;
    if (errorMessage != null) item.errorMessage = errorMessage;
    notifyListeners();
  }

  void cancel() {
    _cancelled = true;
    notifyListeners();
  }

  void clear() {
    _items = [];
    _cancelled = false;
    notifyListeners();
  }
}
