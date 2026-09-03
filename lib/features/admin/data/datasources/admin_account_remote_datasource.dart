import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';

abstract class AdminAccountRemoteDatasource {
  Future<void> updateRole({required String userId, required String role});
}

class AdminAccountRemoteDatasourceImpl implements AdminAccountRemoteDatasource {
  final SupabaseClient supabaseClient;

  AdminAccountRemoteDatasourceImpl({required this.supabaseClient});

  @override
  Future<void> updateRole({required String userId, required String role}) async {
    try {
      await supabaseClient
          .from('profiles')
          .update({'role': role})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
