// lib/core/error/failures.dart

/// Base class for all domain-level failures.
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class LockedRecordFailure extends Failure {
  const LockedRecordFailure(super.message);
}

class OverpaymentFailure extends Failure {
  const OverpaymentFailure(super.message);
}

class NegativeStockFailure extends Failure {
  const NegativeStockFailure(super.message);
}
