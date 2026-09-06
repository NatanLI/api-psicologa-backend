import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_auth.dart';

class ApiService {
  // URL oficial da sua API hospedada no Render
  final String baseUrl = "https://api-psicologa-backend.onrender.com";

  Future<String> sendMessage(String message) async {
    final url = Uri.parse('$baseUrl/api/chat');
    
    // Obter o token de autenticação do Firebase do usuário atual, se houver
    final user = FirebaseAuth.instance.currentUser;
    String? idToken;
    if (user != null) {
      idToken = await user.getIdToken();
    }
    
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        if (idToken != null) "Authorization": "Bearer $idToken",
      },
      body: jsonEncode({
        "message": message,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] ?? 'Sem resposta';
    } else {
      throw Exception("Erro no servidor: ${response.statusCode}");
    }
  }
}