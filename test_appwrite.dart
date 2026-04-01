import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final projectId = '69cc14ce000d6ee3e15b';
  final dbId = '69ccd7f98036a2e58f2c';
  final colId = 'rooms';
  
  print('Testing Appwrite Connection to DB...');
  final url = Uri.parse('https://fra.cloud.appwrite.io/v1/databases/\$dbId/collections/\$colId/documents');
  
  final payload = {
    "documentId": "unique()",
    "data": {
      "name": "Test Room",
      "code": "1234",
      "host_name": "Terminal",
      "status": "waiting",
      "is_public": true,
      "max_players": 4,
      "players": ["{}"],
      "game_state": "{}"
    }
  };

  final res = await http.post(
    url,
    headers: {
      'X-Appwrite-Project': projectId,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(payload),
  );
  
  print('Status Code: \${res.statusCode}');
  print('Response Body: \${res.body}');
}
