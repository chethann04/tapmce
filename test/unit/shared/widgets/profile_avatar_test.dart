import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:placement_connect/features/auth/domain/entities/user_profile.dart';
import 'package:placement_connect/shared/presentation/widgets/profile_avatar.dart';

void main() {
  group('ProfileAvatar Widget Tests', () {
    testWidgets('Renders initials when name is provided without image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              name: 'Chethan',
              size: ProfileAvatarSize.medium,
            ),
          ),
        ),
      );

      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('Renders two initials for multi-word name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              name: 'Sumukha H S',
              size: ProfileAvatarSize.large,
            ),
          ),
        ),
      );

      expect(find.text('SS'), findsOneWidget);
    });

    testWidgets('Renders person icon when name is empty and image is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              name: '',
              imageUrl: null,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('Includes proper accessibility semantics label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              name: 'Sakshi',
              imageUrl: null,
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Sakshi profile picture',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('UserProfile Avatar Entity Tests', () {
    test('UserProfile avatarUrl aliases photoUrl', () {
      final profile = UserProfile(
        id: 'user-123',
        role: UserRole.tpo,
        name: 'TPO Officer',
        email: 'tpo@mcehassan.ac.in',
        photoUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.avatarUrl, equals('https://example.com/avatar.jpg'));
    });

    test('UserProfile fromMap correctly parses photo_url and avatar_url fallback', () {
      final profileFromPhotoUrl = UserProfile.fromMap({
        'id': '1',
        'role': 'faculty_coordinator',
        'name': 'Faculty Coordinator',
        'email': 'faculty@mcehassan.ac.in',
        'photo_url': 'https://supabase.local/photo.png',
      });
      expect(profileFromPhotoUrl.photoUrl, equals('https://supabase.local/photo.png'));
      expect(profileFromPhotoUrl.avatarUrl, equals('https://supabase.local/photo.png'));

      final profileFromAvatarUrl = UserProfile.fromMap({
        'id': '2',
        'role': 'student',
        'name': 'Student Name',
        'email': 'student@mcehassan.ac.in',
        'avatar_url': 'https://supabase.local/avatar.png',
      });
      expect(profileFromAvatarUrl.photoUrl, equals('https://supabase.local/avatar.png'));
      expect(profileFromAvatarUrl.avatarUrl, equals('https://supabase.local/avatar.png'));
    });
  });
}
