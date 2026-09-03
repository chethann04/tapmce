import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/application.dart';

part 'student_realtime_provider.g.dart';

/// Provides the raw stream of all application updates across the entire system.
@riverpod
Stream<Application> globalApplicationUpdates(Ref ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();

  return Supabase.instance.client
      .from('applications')
      .stream(primaryKey: ['id'])
      .eq('student_id', user.id)
      .map((maps) => maps.map((m) => Application.fromMap(m)).first);
}

/// A stateful notifier that tracks if the CURRENT student received a realtime update.
/// This is more efficient than making the UI parse every global update.
@riverpod
class StudentRealtimeController extends _$StudentRealtimeController {
  @override
  Application? build() {
    // Get the current user's ID to filter updates
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    // Listen to the global stream via Riverpod ref.listen
    ref.listen<AsyncValue<Application>>(globalApplicationUpdatesProvider, (previous, next) {
      next.whenData((updatedApp) {
        if (updatedApp.studentId == userId) {
          state = updatedApp;
        }
      });
    });

    return null;
  }
}