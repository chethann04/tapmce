// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_realtime_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$globalApplicationUpdatesHash() =>
    r'39ef605760f0067726d88d6d3a1d77d0cfac106b';

/// Provides the raw stream of all application updates across the entire system.
///
/// Copied from [globalApplicationUpdates].
@ProviderFor(globalApplicationUpdates)
final globalApplicationUpdatesProvider =
    AutoDisposeStreamProvider<Application>.internal(
  globalApplicationUpdates,
  name: r'globalApplicationUpdatesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$globalApplicationUpdatesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GlobalApplicationUpdatesRef = AutoDisposeStreamProviderRef<Application>;
String _$studentRealtimeControllerHash() =>
    r'ae1b21cc0c44359d08cc333661b893cfcaefee30';

/// A stateful notifier that tracks if the CURRENT student received a realtime update.
/// This is more efficient than making the UI parse every global update.
///
/// Copied from [StudentRealtimeController].
@ProviderFor(StudentRealtimeController)
final studentRealtimeControllerProvider = AutoDisposeNotifierProvider<
    StudentRealtimeController, Application?>.internal(
  StudentRealtimeController.new,
  name: r'studentRealtimeControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$studentRealtimeControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StudentRealtimeController = AutoDisposeNotifier<Application?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
