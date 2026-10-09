import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:serverpod/serverpod.dart' show Transaction;

/// In-memory [HireLifecycleStore] with the same unique rules as the
/// Serverpod one. Tests set [statusOverride] to put a hire in a state the
/// store cannot reach yet (for example `submitted`).
class InMemoryHireLifecycleStore implements HireLifecycleStore {
  final _rows = <int, HireRow>{};
  var _nextId = 1;

  /// Forces the status [findHire] reports for a hire id.
  final statusOverride = <int, HireStatus?>{};

  /// Every stored hire, in insertion order.
  List<HireRow> get all => List.unmodifiable(_rows.values);

  @override
  Future<HireRow?> findHire(int id) async => _view(_rows[id]);

  @override
  Future<HireRow?> findHireByRequest(String consumer, String requestId) async {
    for (final row in _rows.values) {
      if (row.consumer == consumer && row.requestId == requestId) {
        return _view(row);
      }
    }
    return null;
  }

  @override
  Future<HireRow> insertHire(NewHire hire, {Transaction? transaction}) async {
    final clash = _rows.values.any(
      (r) => r.consumer == hire.consumer && r.requestId == hire.requestId,
    );
    if (clash) throw const HireRequestConflict();
    final row = _row(_nextId++, hire);
    _rows[row.id] = row;
    return row;
  }

  @override
  Future<JobBinding> bindJob(
    int hireId,
    int jobId, {
    required int expiredAt,
  }) async {
    final row = _rows[hireId];
    if (row == null) throw StateError('hire $hireId does not exist');
    if (row.jobId == jobId) return JobBinding.alreadyBound;
    final taken =
        row.jobId != null || _rows.values.any((r) => r.jobId == jobId);
    if (taken) return JobBinding.taken;
    _rows[hireId] = HireRow(
      id: row.id,
      consumer: row.consumer,
      agentId: row.agentId,
      price: row.price,
      manifestVersion: row.manifestVersion,
      expiredAt: expiredAt,
      requestId: row.requestId,
      input: row.input,
      jobId: jobId,
      paymentTransaction: row.paymentTransaction,
      status: HireStatus.open,
    );
    return JobBinding.bound;
  }

  HireRow? _view(HireRow? row) {
    if (row == null || !statusOverride.containsKey(row.id)) return row;
    return HireRow(
      id: row.id,
      consumer: row.consumer,
      agentId: row.agentId,
      price: row.price,
      manifestVersion: row.manifestVersion,
      expiredAt: row.expiredAt,
      requestId: row.requestId,
      input: row.input,
      jobId: row.jobId,
      paymentTransaction: row.paymentTransaction,
      status: statusOverride[row.id],
    );
  }

  HireRow _row(int id, NewHire hire) => HireRow(
    id: id,
    consumer: hire.consumer,
    agentId: hire.agentId,
    price: hire.price,
    manifestVersion: hire.manifestVersion,
    expiredAt: hire.expiredAt,
    requestId: hire.requestId,
    input: hire.input,
    jobId: null,
    paymentTransaction: null,
    status: null,
  );
}
