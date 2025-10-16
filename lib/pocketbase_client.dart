import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final PocketBase pb;

Future<void> initPocketBase() async {
  final prefs = await SharedPreferences.getInstance();

  final store = AsyncAuthStore(
    save:    (String data) async => prefs.setString('pb_auth', data),
    initial: prefs.getString('pb_auth'), 
  );

  pb = PocketBase(
    'http://127.0.0.1:8090',
    authStore: store,
  );
}