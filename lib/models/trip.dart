class Trip {
  final String id;
  final String driverId;
  final String tripDate;
  final String? observations;
  final DateTime? createdAt;

  const Trip({
    required this.id,
    required this.driverId,
    required this.tripDate,
    this.observations,
    this.createdAt,
  });

  /// Ventana de 24h desde la creación para editar/eliminar el viaje.
  /// Sin fecha de creación conocida no se permite modificar.
  bool get isEditable =>
      createdAt != null &&
      DateTime.now().difference(createdAt!) < const Duration(hours: 24);

  static DateTime? _parseCreatedAt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory Trip.fromMap(Map<String, dynamic> map) => Trip(
        id: map['id'] as String,
        driverId: map['driver_id'] as String,
        tripDate: (map['trip_date'] ?? '') as String,
        observations: map['observations'] as String?,
        createdAt: _parseCreatedAt(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'driver_id': driverId,
        'trip_date': tripDate,
        'observations': observations,
      }..removeWhere((_, v) => v == null);
}

class TripPassenger {
  final String id;
  final String tripId;
  final String departure;
  final String arrival;
  final double cost;
  final String paymentMethod;

  const TripPassenger({
    required this.id,
    required this.tripId,
    required this.departure,
    required this.arrival,
    required this.cost,
    required this.paymentMethod,
  });

  String get route => '$departure -> $arrival';
  bool get isCompanyPaid => paymentMethod == 'Empresa';

  factory TripPassenger.fromMap(Map<String, dynamic> map) => TripPassenger(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        departure: (map['departure'] ?? '') as String,
        arrival: (map['arrival'] ?? '') as String,
        cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: (map['payment_method'] ?? 'Efectivo') as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'departure': departure,
        'arrival': arrival,
        'cost': cost,
        'payment_method': paymentMethod,
      };
}

class TripPackage {
  final String id;
  final String tripId;
  final String departure;
  final String arrival;
  final double cost;
  final String paymentMethod;

  const TripPackage({
    required this.id,
    required this.tripId,
    required this.departure,
    required this.arrival,
    required this.cost,
    required this.paymentMethod,
  });

  String get route => '$departure -> $arrival';
  bool get isCompanyPaid => paymentMethod == 'Empresa';

  factory TripPackage.fromMap(Map<String, dynamic> map) => TripPackage(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        departure: (map['departure'] ?? '') as String,
        arrival: (map['arrival'] ?? '') as String,
        cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: (map['payment_method'] ?? 'Efectivo') as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'departure': departure,
        'arrival': arrival,
        'cost': cost,
        'payment_method': paymentMethod,
      };
}

class TripExpense {
  final String id;
  final String tripId;
  final String category;
  final String? detail;
  final double amount;

  const TripExpense({
    required this.id,
    required this.tripId,
    required this.category,
    this.detail,
    required this.amount,
  });

  bool get isRefundableCategory =>
      category == 'Gasolina' ||
      category == 'Conductor' ||
      category == 'Peajes' ||
      category == 'Otros';

  factory TripExpense.fromMap(Map<String, dynamic> map) => TripExpense(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        category: (map['category'] ?? 'Otros') as String,
        detail: map['detail'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'category': category,
        'detail': detail,
        'amount': amount,
      }..removeWhere((_, v) => v == null);
}
