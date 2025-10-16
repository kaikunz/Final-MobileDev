import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

Future<void> main() async {
  const baseUrl = 'http://127.0.0.1:8090';
  const email = 'admin@ubu.ac.th';
  const password = '1234567890';

  final pb = PocketBase(baseUrl);

  print('🔹 Logging in as superuser...');
  try {
    await pb.collection("_superusers").authWithPassword(email, password);
    print('✅ Superuser login success');
  } catch (e) {
    print('❌ Login failed: $e');
    return;
  }

  final token = pb.authStore.token;
  print('🔑 Token acquired: $token\n');

  // ✅ 1️⃣ สร้าง collection: post
  final postPayload = {
    "id": "",
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": "",
    "name": "post",
    "type": "base",
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": r"^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text",
        "_originalName": "id",
        "_toDelete": false,
        "nullable": false
      },
      {
        "id": "",
        "name": "title",
        "type": "text",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "content",
        "type": "text",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "authorId",
        "type": "relation",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "maxSelect": 1,
        "collectionId": "_pb_users_auth_",
        "cascadeDelete": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "upvotes",
        "type": "number",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "downvotes",
        "type": "number",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "type": "autodate",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "_originalName": "created",
        "_toDelete": false
      },
      {
        "type": "autodate",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "_originalName": "updated",
        "_toDelete": false
      }
    ],
    "indexes": [],
    "created": "",
    "updated": "",
    "system": false,
    "_originalName": ""
  };

  print('📦 Creating collection: post...');
  final postRes = await http.post(
    Uri.parse('$baseUrl/api/collections'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(postPayload),
  );

  if (postRes.statusCode != 200) {
    print('⚠️ Failed to create post: ${postRes.statusCode}');
    print(postRes.body);
    return;
  }

  final postData = jsonDecode(postRes.body);
  final postId = postData['id'];
  print('✅ Created post successfully (id: $postId)\n');

  // ✅ 2️⃣ สร้าง collection: comment
  final commentPayload = {
    "id": "",
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": "",
    "name": "comment",
    "type": "base",
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": r"^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text",
        "_originalName": "id",
        "_toDelete": false,
        "nullable": false
      },
      {
        "id": "",
        "name": "postId",
        "type": "relation",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "maxSelect": 1,
        "collectionId": postId, // ✅ ใช้ id ของ post
        "cascadeDelete": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "authorId",
        "type": "relation",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "maxSelect": 1,
        "collectionId": "_pb_users_auth_",
        "cascadeDelete": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "content",
        "type": "text",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "type": "autodate",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "_originalName": "created",
        "_toDelete": false
      },
      {
        "type": "autodate",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "_originalName": "updated",
        "_toDelete": false
      }
    ],
    "indexes": [],
    "created": "",
    "updated": "",
    "system": false,
    "_originalName": ""
  };

  print('📦 Creating collection: comment...');
  final commentRes = await http.post(
    Uri.parse('$baseUrl/api/collections'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(commentPayload),
  );

  if (commentRes.statusCode != 200) {
    print('⚠️ Failed to create comment: ${commentRes.statusCode}');
    print(commentRes.body);
    return;
  }

  print('✅ Created comment successfully\n');

  // ✅ 3️⃣ สร้าง collection: Vote
  final votePayload = {
    "id": "",
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": "",
    "name": "vote",
    "type": "base",
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": r"^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text",
        "_originalName": "id",
        "_toDelete": false,
        "nullable": false
      },
      {
        "id": "",
        "name": "postId",
        "type": "relation",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "maxSelect": 1,
        "collectionId": postId, // ✅ ใช้ id ของ post
        "cascadeDelete": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "userId",
        "type": "relation",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "maxSelect": 1,
        "collectionId": "_pb_users_auth_",
        "cascadeDelete": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "id": "",
        "name": "type",
        "type": "text",
        "system": false,
        "hidden": false,
        "required": false,
        "onMountSelect": false,
        "_originalName": "field",
        "_toDelete": false
      },
      {
        "type": "autodate",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "_originalName": "created",
        "_toDelete": false
      },
      {
        "type": "autodate",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "_originalName": "updated",
        "_toDelete": false
      }
    ],
    "indexes": [],
    "created": "",
    "updated": "",
    "system": false,
    "_originalName": ""
  };

  print('📦 Creating collection: Vote...');
  final voteRes = await http.post(
    Uri.parse('$baseUrl/api/collections'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(votePayload),
  );

  if (voteRes.statusCode == 200) {
    print('✅ Created Vote successfully');
  } else {
    print('⚠️ Failed to create Vote: ${voteRes.statusCode}');
    print(voteRes.body);
  }

  print('\n🏁 All collections created successfully.');
}
