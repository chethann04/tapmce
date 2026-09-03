import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// Failures returned to the Presentation Layer.
/// The UI should never see Exceptions, only Failures.
@freezed
class Failure with _$Failure {
  const factory Failure.server({
    required String message,
    String? code,
  }) = ServerFailure;

  const factory Failure.network({
    required String message,
  }) = NetworkFailure;

  const factory Failure.auth({
    required String message,
    String? code,
  }) = AuthFailure;

  const factory Failure.unauthorized({
    required String message,
  }) = UnauthorizedFailure;

  const factory Failure.cache({
    required String message,
  }) = CacheFailure;

  const factory Failure.validation({
    required String message,
    String? field,
  }) = ValidationFailure;
}