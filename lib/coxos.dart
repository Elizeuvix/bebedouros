import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'config_screen.dart';
import 'internet_helper.dart';

class Coxo {
  final String coxoId;
  final String coxoData;
  final String nextData;

  Coxo({required this.coxoId, required this.coxoData, required this.nextData});

  factory Coxo.fromJson(Map<String, dynamic> json) {
    return Coxo(
      coxoId: json['coxo_id'] ?? '',
      coxoData: json['coxo_data'] ?? '',
      nextData: json['next_data'] ?? '',
    );
  }
}

class CoxosPage extends StatefulWidget {
  const CoxosPage({Key? key}) : super(key: key);

  @override
  State<CoxosPage> createState() => _CoxosPageState();
}

class _CoxosPageState extends State<CoxosPage> {
  String? _lastSyncUrl;
  bool _syncAvailable = false;
  bool _syncing = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _loadCoxos();
    _checkSyncAvailable();
  }

  Future<void> _checkSyncAvailable() async {
    final hasInternet = await checkInternet();
    setState(() {
      _syncAvailable = hasInternet;
    });
  }

  Future<void> _syncCoxos() async {
    // ...existing code...
    final directory = await getApplicationDocumentsDirectory();
    // Lê nome do usuário salvo em user.json
    String usuarioNome = '';
    final userFile = File('${directory.path}/user.json');
    if (await userFile.exists()) {
      final userContent = await userFile.readAsString();
      final userJson = jsonDecode(userContent);
      usuarioNome = userJson['nome'] ?? '';
    }
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
        hostUrl = hostJson['host_url'] ?? '';

        print('DEBUG HOST URL: $hostUrl');
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

      print('DEBUG URL de sincronização: $fullUrl');

      int successCount = 0;
      int failCount = 0;
      for (var item in coxosList) {
        final response = await http.post(
          Uri.parse(fullUrl),
          body: {
            'coxo_idPost': item['coxo_id'] ?? '',
            'data_manutPost': item['coxo_data'] ?? '',
            'usuarioPost': usuarioNome,
          },
        );
        if (response.statusCode == 200) {
          final respJson = jsonDecode(response.body);
          setState(() {
            _lastSyncUrl = fullUrl;
          });
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
        _syncMessage =
            'Sincronização concluída: $successCount enviados, $failCount falharam.';
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

  List<Coxo> _coxos = [];
  bool _loading = true;
  bool _loadingHttp = false;
  String? _httpMessage;

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/coxos.json';
  }

  Future<void> _loadCoxos() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        setState(() {
          _coxos = jsonList.map((e) => Coxo.fromJson(e)).toList();
        });
      }
    } catch (e) {
      setState(() {
        _coxos = [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveCoxos() async {
    final path = await _getFilePath();
    final file = File(path);
    final list = _coxos
        .map(
          (c) => {
            'coxo_id': c.coxoId,
            'coxo_data': c.coxoData,
            'next_data': c.nextData,
          },
        )
        .toList();
    await file.writeAsString(jsonEncode(list));
  }

  Future<void> _loadCoxosFromWeb() async {
    setState(() {
      _loadingHttp = true;
      _httpMessage = null;
    });
    try {
      // Lê host salvo em host.json
      final directory = await getApplicationDocumentsDirectory();
      final hostFile = File('${directory.path}/host.json');
      String hostUrl = '';
      if (await hostFile.exists()) {
        final hostContent = await hostFile.readAsString();
        final hostJson = jsonDecode(hostContent);
        hostUrl = hostJson['host_url'] ?? '';
      }
      if (hostUrl.isEmpty) {
        setState(() {
          _httpMessage = 'Host não configurado.';
        });
        // Abre a tela de configuração
        Future.delayed(Duration.zero, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ConfigScreen()),
          );
        });
        return;
      }
      final fullUrl = hostUrl.endsWith('/')
          ? '${hostUrl}read_manutencao.php'
          : '$hostUrl/read_manutencao.php';
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<Map<String, dynamic>> coxosToSave = [];
        for (var item in jsonList) {
          final coxoId = item['coxo_id'] ?? '';
          final coxoData = item['data_manut'] ?? '';
          DateTime? data;
          try {
            data = DateTime.parse(coxoData);
          } catch (_) {
            data = null;
          }
          String nextData = '';
          if (data != null) {
            nextData = data
                .add(const Duration(days: 7))
                .toIso8601String()
                .split('T')[0];
          }
          coxosToSave.add({
            'coxo_id': coxoId,
            'coxo_data': coxoData,
            'next_data': nextData,
          });
        }
        final path = await _getFilePath();
        final file = File(path);
        await file.writeAsString(jsonEncode(coxosToSave));
        setState(() {
          _httpMessage = 'Coxos atualizados com sucesso!';
        });
        await _loadCoxos();
      } else {
        setState(() {
          _httpMessage = 'Erro ao carregar dados (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _httpMessage = 'Erro: $e';
      });
    } finally {
      setState(() {
        _loadingHttp = false;
      });
    }
  }

  Future<void> _addOrEditCoxo({Coxo? coxo, int? index}) async {
    final idController = TextEditingController(text: coxo?.coxoId ?? '');
    final dataController = TextEditingController(text: coxo?.coxoData ?? '');
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(coxo == null ? 'Novo Coxo' : 'Editar Coxo'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'Coxo ID'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o ID' : null,
                ),
                TextFormField(
                  controller: dataController,
                  decoration: const InputDecoration(
                    labelText: 'Data (dd/MM/yyyy)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a data';
                    try {
                      DateTime.parse(v);
                      return null;
                    } catch (_) {
                      return 'Data inválida';
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final coxoId = idController.text.trim();
                  final coxoData = dataController.text.trim();
                  final nextData = DateTime.parse(coxoData)
                      .add(const Duration(days: 7))
                      .toIso8601String()
                      .split('T')[0];
                  final newCoxo = Coxo(
                    coxoId: coxoId,
                    coxoData: coxoData,
                    nextData: nextData,
                  );
                  setState(() {
                    if (index != null) {
                      _coxos[index] = newCoxo;
                    } else {
                      _coxos.add(newCoxo);
                    }
                  });
                  await _saveCoxos();
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coxos'),
        actions: [
          FutureBuilder<bool>(
            future: checkInternet(),
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return IconButton(
                icon: const Icon(Icons.cloud_download),
                tooltip: isOnline ? 'Load Coxos' : 'Sem conexão',
                onPressed: (_loadingHttp || !isOnline)
                    ? null
                    : _loadCoxosFromWeb,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingHttp) const LinearProgressIndicator(),
          if (_httpMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _httpMessage!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar Dados'),
              onPressed: _syncAvailable && !_syncing ? _syncCoxos : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
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
              child: Text(
                _syncMessage!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _coxos.isEmpty
                ? const Center(child: Text('Nenhum registro encontrado.'))
                : ListView.builder(
                    itemCount: _coxos.length,
                    itemBuilder: (context, index) {
                      final coxo = _coxos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text('ID: ${coxo.coxoId}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Data: ${coxo.coxoData}'),
                              Text('Próxima Data: ${coxo.nextData}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _addOrEditCoxo(coxo: coxo, index: index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCoxo(),
        child: const Icon(Icons.add),
        tooltip: 'Adicionar Coxo',
      ),
    );
  }
}
