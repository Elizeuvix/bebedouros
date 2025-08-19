import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'coxos.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identificação do Usuário',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const UserIdentificationPage(),
    );
  }
}


class UserIdentificationPage extends StatefulWidget {
  const UserIdentificationPage({Key? key}) : super(key: key);

  @override
  State<UserIdentificationPage> createState() => _UserIdentificationPageState();
}

class _UserIdentificationPageState extends State<UserIdentificationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  String? _message;

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/user.json';
  }

  Future<void> _saveUserData() async {
    final name = _nameController.text.trim();
    final role = _roleController.text.trim();
    if (name.isEmpty || role.isEmpty) {
      setState(() {
        _message = 'Preencha todos os campos.';
      });
      return;
    }
    final data = jsonEncode({'nome': name, 'funcao': role});
    final path = await _getFilePath();
    final file = File(path);
    await file.writeAsString(data);
    setState(() {
      _message = 'Dados salvos com sucesso!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identificação do Usuário')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(labelText: 'Função'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveUserData,
              child: const Text('Salvar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoxosPage()),
                );
              },
              child: const Text('Abrir Coxos'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, style: const TextStyle(color: Colors.green)),
            ]
          ],
        ),
      ),
    );
  }
}
