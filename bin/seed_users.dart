import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placement_connect/core/constants/app_constants.dart';

void main() async {
  print('Initializing Supabase client...');
  
  // Initialize Supabase Flutter SDK headless
  final client = SupabaseClient(
    AppConstants.supabaseUrl,
    AppConstants.supabaseAnonKey,
  );

  final demoUsers = [
    {
      'email': 'admin@gmail.com',
      'password': 'admin123Password!',
      'name': 'System Administrator',
      'role': 'admin',
      'dept': 'Administration',
    },
    {
      'email': 'tap@gmail.com',
      'password': 'tap123Password!',
      'name': 'Placement Officer (TPO)',
      'role': 'tpo',
      'dept': 'Training & Placement Cell',
    },
    {
      'email': 'facultycse@gmail.com',
      'password': 'cse123Password!',
      'name': 'Dr. CSE Faculty',
      'role': 'faculty',
      'dept': 'Computer Science & Engineering',
    },
    {
      'email': 'facultymech@gmail.com',
      'password': 'mech123Password!',
      'name': 'Prof. Mech Faculty',
      'role': 'faculty',
      'dept': 'Mechanical Engineering',
    },
    {
      'email': 'stud1@gmail.com',
      'password': 'stud123Password!',
      'name': 'Student One (CSE)',
      'role': 'student',
      'dept': 'Computer Science & Engineering',
      'roll': '4MC23CS001',
      'cgpa': 8.5,
    },
    {
      'email': 'stud2@gmail.com',
      'password': 'stud123Password!',
      'name': 'Student Two (ISE)',
      'role': 'student',
      'dept': 'Information Science & Engineering',
      'roll': '4MC23IS002',
      'cgpa': 7.9,
    },
  ];

  print('\n=== Creating Demo Accounts in Supabase ===\n');

  for (final user in demoUsers) {
    final email = user['email'] as String;
    final password = user['password'] as String;
    final name = user['name'] as String;
    final role = user['role'] as String;
    final dept = user['dept'] as String?;
    final roll = user['roll'] as String?;

    try {
      print('Registering $email ($role)...');
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': role,
          if (dept != null) 'department': dept,
          if (roll != null) 'roll_number': roll,
        },
      );

      if (res.user != null) {
        print('  ✅ Created user ID: ${res.user!.id}');
        
        // Also insert profile record explicitly into public.profiles
        try {
          await client.from('profiles').upsert({
            'id': res.user!.id,
            'email': email,
            'full_name': name,
            'role': role,
            'department': dept,
            'roll_number': roll,
            'is_email_verified': true,
          });
          print('  ✅ Profile created/updated');
        } catch (e) {
          print('  ⚠️ Profile insert warning: $e');
        }
      } else {
        print('  ⚠️ Warning: User response was null for $email');
      }
    } catch (e) {
      if (e.toString().contains('already registered') || e.toString().contains('already been registered')) {
        print('  ℹ️ Account $email already exists');
      } else {
        print('  ❌ Error creating $email: $e');
      }
    }
  }

  print('\n=== User Creation Complete ===');
}
