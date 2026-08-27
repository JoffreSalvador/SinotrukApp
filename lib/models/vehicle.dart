class Vehicle {
  final String id;
  final String plate;
  final String? brand;
  final String? model;

  const Vehicle({required this.id, required this.plate, this.brand, this.model});

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as String,
        plate: (map['plate'] ?? '') as String,
        brand: map['brand'] as String?,
        model: map['model'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'plate': plate,
        'brand': brand,
        'model': model,
      }..removeWhere((_, v) => v == null);
}

class VehicleAssignment {
  final String id;
  final String vehicleId;
  final String driverId;
  final bool isActive;
  final String assignedDate;
  final String? unassignedDate;

  const VehicleAssignment({
    required this.id,
    required this.vehicleId,
    required this.driverId,
    this.isActive = true,
    required this.assignedDate,
    this.unassignedDate,
  });

  factory VehicleAssignment.fromMap(Map<String, dynamic> map) =>
      VehicleAssignment(
        id: map['id'] as String,
        vehicleId: map['vehicle_id'] as String,
        driverId: map['driver_id'] as String,
        isActive: map['is_active'] == null ||
            map['is_active'] == 1 ||
            map['is_active'] == true,
        assignedDate: (map['assigned_date'] ?? '') as String,
        unassignedDate: map['unassigned_date'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'is_active': isActive,
        'assigned_date': assignedDate,
        'unassigned_date': unassignedDate,
      }..removeWhere((_, v) => v == null);
}

class VehicleExpense {
  final String id;
  final String vehicleId;
  final String expenseDate;
  final String detail;
  final double amount;

  const VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.expenseDate,
    required this.detail,
    required this.amount,
  });

  factory VehicleExpense.fromMap(Map<String, dynamic> map) => VehicleExpense(
        id: map['id'] as String,
        vehicleId: map['vehicle_id'] as String,
        expenseDate: (map['expense_date'] ?? '') as String,
        detail: (map['detail'] ?? '') as String,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'expense_date': expenseDate,
        'detail': detail,
        'amount': amount,
      };
}
