enum PaymentType { efectivo, empresa }

extension PaymentTypeX on PaymentType {
  String get dbValue => this == PaymentType.efectivo ? 'Efectivo' : 'Empresa';

  static PaymentType fromDb(String value) =>
      value == 'Empresa' ? PaymentType.empresa : PaymentType.efectivo;
}

enum ExpenseCategory { gasolina, conductor, peajes, otros }

extension ExpenseCategoryX on ExpenseCategory {
  String get dbValue {
    switch (this) {
      case ExpenseCategory.gasolina:
        return 'Gasolina';
      case ExpenseCategory.conductor:
        return 'Conductor';
      case ExpenseCategory.peajes:
        return 'Peajes';
      case ExpenseCategory.otros:
        return 'Otros';
    }
  }

  static ExpenseCategory fromDb(String value) {
    switch (value) {
      case 'Gasolina':
        return ExpenseCategory.gasolina;
      case 'Conductor':
        return ExpenseCategory.conductor;
      case 'Peajes':
        return ExpenseCategory.peajes;
      default:
        return ExpenseCategory.otros;
    }
  }
}

enum DriverTxType { pagoRecibido, pagoRealizado }

extension DriverTxTypeX on DriverTxType {
  String get dbValue =>
      this == DriverTxType.pagoRecibido ? 'PagoRecibido' : 'PagoRealizado';

  static DriverTxType fromDb(String value) => value == 'PagoRecibido'
      ? DriverTxType.pagoRecibido
      : DriverTxType.pagoRealizado;
}

enum ManagerTxType { pagoRecibido, pagoRealizado, manualPorPagar, manualPorCobrar }

extension ManagerTxTypeX on ManagerTxType {
  String get dbValue {
    switch (this) {
      case ManagerTxType.pagoRecibido:
        return 'PagoRecibido';
      case ManagerTxType.pagoRealizado:
        return 'PagoRealizado';
      case ManagerTxType.manualPorPagar:
        return 'ManualPorPagar';
      case ManagerTxType.manualPorCobrar:
        return 'ManualPorCobrar';
    }
  }

  static ManagerTxType fromDb(String value) {
    switch (value) {
      case 'PagoRecibido':
        return ManagerTxType.pagoRecibido;
      case 'PagoRealizado':
        return ManagerTxType.pagoRealizado;
      case 'ManualPorCobrar':
        return ManagerTxType.manualPorCobrar;
      default:
        return ManagerTxType.manualPorPagar;
    }
  }
}
