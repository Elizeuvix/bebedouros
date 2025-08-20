import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'coxos.dart';
import 'config_screen.dart';
import 'internet_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _ensureHostFile().then((_) {
    runApp(const MyApp());
  });
}

Future<void> _ensureHostFile() async {
  final directory = await getApplicationDocumentsDirectory();
  final hostFile = File('${directory.path}/host.json');
  if (!await hostFile.exists()) {
    await hostFile.writeAsString(jsonEncode({'host': 'http://192.168.3.196/coxos/'}));
  }
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
  bool _syncAvailable = false;
  bool _syncing = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _loadUserDataIfExists();
    _checkSyncAvailable();
  }

  Future<void> _checkSyncAvailable() async {
    final hasInternet = await checkInternet();
    final directory = await getApplicationDocumentsDirectory();
    final coxosFile = File('${directory.path}/coxos.json');
    bool hasChanges = false;
    if (await coxosFile.exists()) {
      final lastModified = await coxosFile.lastModified();
      // Simples: considera que se o arquivo foi modificado nos últimos 5 minutos, há alteração
      hasChanges = DateTime.now().difference(lastModified).inMinutes < 5;
    }
    setState(() {
      _syncAvailable = hasInternet && hasChanges;
    });
  }

  Future<void> _syncCoxos() async {
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });
    try {
      final directory = await getApplicationDocumentsDirectory();
      final hostFile = File('${directory.path}/host.json');
      String hostUrl = '';
      if (await hostFile.exists()) {
        final hostContent = await hostFile.readAsString();
        final hostJson = jsonDecode(hostContent);
        hostUrl = hostJson['host'] ?? '';
      }
      if (hostUrl.isEmpty) {
        setState(() {
          _syncMessage = 'Host não configurado.';
        });
        return;
      }
      final coxosFile = File('${directory.path}/coxos.json');
      if (!await coxosFile.exists()) {
        setState(() {
          _syncMessage = 'Arquivo coxos.json não encontrado.';
        });
        return;
      }
      final coxosData = await coxosFile.readAsString();
      final List<dynamic> coxosList = jsonDecode(coxosData);
      final fullUrl = hostUrl.endsWith('/')
        ? '${hostUrl}insert_manutencao.php'
        : '$hostUrl/insert_manutencao.php';
      int successCount = 0;
      int failCount = 0;
      for (var item in coxosList) {
        final response = await http.post(
          Uri.parse(fullUrl),
          body: {
            'coxo_idPost': item['coxo_id'] ?? '',
            'data_manutPost': item['coxo_data'] ?? '',
            'usuarioPost': item['usuario'] ?? '',
          },
        );
        if (response.statusCode == 200) {
          final respJson = jsonDecode(response.body);
          if (respJson['success'] == true) {
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      }
      setState(() {
        _syncMessage = 'Sincronização concluída: $successCount enviados, $failCount falharam.';
      });
    } catch (e) {
      setState(() {
        _syncMessage = 'Erro: $e';
      });
    } finally {
      setState(() {
        _syncing = false;
      });
      _checkSyncAvailable();
    }
  }
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  String? _message;

  // Duplicate initState removed. The correct initState is defined above.

  Future<void> _loadUserDataIfExists() async {
    final path = await _getFilePath();
    final file = File(path);
    if (await file.exists()) {
      final content = await file.readAsString();
      final jsonData = jsonDecode(content);
      _nameController.text = jsonData['nome'] ?? '';
      _roleController.text = jsonData['funcao'] ?? '';
    }
  }

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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar Dados'),
              onPressed: _syncAvailable && !_syncing ? _syncCoxos : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (_syncing)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
              ),
            if (_syncMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_syncMessage!, style: const TextStyle(color: Colors.green)),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Configurações'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConfigScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
