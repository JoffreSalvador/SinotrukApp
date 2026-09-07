class DriverAccountEntry {
  final String id;
  final String driverId;
  final String txType;
  final String txDate;
  final String detail;
  final double amount;

  const DriverAccountEntry({
    required this.id,
    required this.driverId,
    required this.txType,
    required this.txDate,
    required this.detail,
    required this.amount,
  });

  bool get isPagoRecibido => txType == 'PagoRecibido';
  bool get isPagoRealizado => txType == 'PagoRealizado';

  factory DriverAccountEntry.fromMap(Map<String, dynamic> map) =>
      DriverAccountEntry(
        id: map['id'] as String,
        driverId: map['driver_id'] as String,
        txType: (map['tx_type'] ?? 'PagoRecibido') as String,
        txDate: (map['tx_date'] ?? '') as String,
        detail: (map['detail'] ?? '') as String,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'driver_id': driverId,
        'tx_type': txType,
        'tx_date': txDate,
        'detail': detail,
        'amount': amount,
      };
}

class ManagerAccountEntry {
  final String id;
  final String txType;
  final String txDate;
  final String detail;
  final double amount;
  final String source;
  final String? relatedTripId;
  final DateTime? createdAt;

  const ManagerAccountEntry({
    required this.id,
    required this.txType,
    required this.txDate,
    required this.detail,
    required this.amount,
    this.source = 'manual',
    this.relatedTripId,
    this.createdAt,
  });

  bool get isAutomatic => source == 'auto';
  bool get isPorCobrar => txType == 'ManualPorCobrar';
  bool get isPagoRecibido => txType == 'PagoRecibido';
  bool get isPagoRealizado => txType == 'PagoRealizado';

  static DateTime? _parseCreatedAt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory ManagerAccountEntry.fromMap(Map<String, dynamic> map) =>
      ManagerAccountEntry(
        id: map['id'] as String,
        txType: (map['tx_type'] ?? 'PagoRecibido') as String,
        txDate: (map['tx_date'] ?? '') as String,
        detail: (map['detail'] ?? '') as String,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        source: (map['source'] ?? 'manual') as String,
        relatedTripId: map['related_trip_id'] as String?,
        createdAt: _parseCreatedAt(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'tx_type': txType,
        'tx_date': txDate,
        'detail': detail,
        'amount': amount,
        'source': source,
        'related_trip_id': relatedTripId,
      }..removeWhere((_, v) => v == null);
}
