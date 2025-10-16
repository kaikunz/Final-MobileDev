import 'package:pocketbase/pocketbase.dart';
import 'package:faker/faker.dart';

Future<void> main() async {
  const baseUrl = 'http://127.0.0.1:8090';
  const superEmail = 'admin@ubu.ac.th';
  const superPassword = '1234567890';

  final pb = PocketBase(baseUrl);
  final faker = Faker();

  // 1️⃣ login superuser
  print('🔹 Logging in as superuser...');
  try {
    await pb.collection("_superusers").authWithPassword(superEmail, superPassword);
    print('✅ Superuser login success\n');
  } catch (e) {
    print('❌ Login failed: $e');
    return;
  }

  // 2️⃣ ตรวจสอบว่ามี user ชื่อ "demo_author" หรือยัง
  print('🔍 Checking for existing demo user...');
  String? authorId;

  try {
    final users = await pb.collection('users').getList(
      page: 1,
      perPage: 1,
      filter: 'email="example@demo_author.com"',
    );

    if (users.items.isNotEmpty) {
      authorId = users.items.first.id;
      print('✅ Found existing demo user (id: $authorId)\n');
    } else {
      final newUser = await pb.collection('users').create(body: {
        'email': "example@demo_author.com",
        'password': "1234567890",
        'passwordConfirm': "1234567890",
        'name': "Faker",
      });

      authorId = newUser.id;
      print('✅ Created new demo user (id: $authorId)\n');
    }
  } catch (e) {
    print('⚠️ Failed to check or create user: $e');
    return;
  }

  // 3️⃣ สร้างโพสต์สุ่ม 10 อัน
  print('🧱 Creating 50 fake posts...\n');

  for (int i = 1; i <= 50; i++) {
    final title = faker.lorem.sentence();
    final content =
        faker.lorem.sentences(faker.randomGenerator.integer(5, min: 2)).join(" ");
    final upvotes = faker.randomGenerator.integer(200, min: 0);
    final downvotes = faker.randomGenerator.integer(50, min: 0);

    try {
      final record = await pb.collection('post').create(body: {
        "title": title,
        "content": content,
        "upvotes": upvotes,
        "downvotes": downvotes,
        "authorId": authorId,
      });

      print('✅ [${i.toString().padLeft(2, '0')}] Created post "${record.data["title"]}"');
    } catch (e) {
      print('⚠️ Failed to create post $i: $e');
    }
  }

  print('\n🏁 Finished seeding 10 posts for user demo_author.');
}
