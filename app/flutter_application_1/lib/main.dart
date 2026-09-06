import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // Importante para inicializar o Firebase

void main() async {
  // Garante que os widgets do Flutter estejam prontos antes de chamar serviços nativos
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase no app (necessário para o Web, Android e iOS)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Erro ao inicializar o Firebase: $e");
  }

  runApp(const PsicologaApp());
}

// ==========================================
// 1. SERVIÇO DE API (Isolado)
// ==========================================
class ApiService {
  final String baseUrl = "https://api-psicologa-backend.onrender.com";

  Future<String> sendMessage(String message) async {
    final url = Uri.parse('$baseUrl/api/chat');
    
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

// ==========================================
// 2. APLICATIVO PRINCIPAL
// ==========================================
class PsicologaApp extends StatelessWidget {
  const PsicologaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psicóloga IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

// ==========================================
// 3. TELA DE CHAT
// ==========================================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // Instancia o serviço que comunica com o Render
  final ApiService _apiService = ApiService();

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      // Chama a API separada através do serviço
      final aiResponse = await _apiService.sendMessage(text);

      setState(() {
        _messages.add({'sender': 'ai', 'text': aiResponse});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'ai', 'text': 'Erro de conexão com o backend no Render.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente Virtual'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.teal.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}