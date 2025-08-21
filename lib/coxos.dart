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
    // Converte data do padrão americano para dd/MM/yyyy
    String coxoData = json['coxo_data'] ?? '';
    String nextData = '';
    try {
      if (coxoData.isNotEmpty) {
        // Aceita dd/MM/yyyy ou yyyy-MM-dd
        DateTime dt;
        if (coxoData.contains('/')) {
          final partes = coxoData.split('/');
          dt = DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
        } else if (coxoData.contains('-')) {
          final partes = coxoData.split('-');
          dt = DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
        } else {
          dt = DateTime.parse(coxoData);
        }
        coxoData = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        final nextDt = dt.add(const Duration(days: 7));
        nextData = '${nextDt.day.toString().padLeft(2, '0')}/${nextDt.month.toString().padLeft(2, '0')}/${nextDt.year}';
      }
    } catch (_) {
      nextData = '';
    }
    return Coxo(
      coxoId: json['coxo_id'] ?? '',
      coxoData: coxoData,
      nextData: nextData,
    );
  }
}

class CoxosPage extends StatefulWidget {
  const CoxosPage({Key? key}) : super(key: key);

  @override
  State<CoxosPage> createState() => _CoxosPageState();
}

class _CoxosPageState extends State<CoxosPage> {
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
    });
  }

  Future<void> _syncCoxos() async {
    final directory = await getApplicationDocumentsDirectory();
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
        final Map<String, dynamic> respJson = jsonDecode(response.body);
        final List<dynamic> jsonList = respJson['data'] ?? [];
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
                    final regex = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
                    if (!regex.hasMatch(v)) return 'Data inválida';
                    try {
                      final partes = v.split('/');
                      final dia = int.parse(partes[0]);
                      final mes = int.parse(partes[1]);
                      final ano = int.parse(partes[2]);
                      DateTime(ano, mes, dia);
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
                  final coxoDataStr = dataController.text.trim();
                  // Salva e exibe sempre em dd/MM/yyyy
                  DateTime coxoData;
                  try {
                    final partes = coxoDataStr.split('/');
                    coxoData = DateTime(
                      int.parse(partes[2]),
                      int.parse(partes[1]),
                      int.parse(partes[0]),
                    );
                  } catch (_) {
                    coxoData = DateTime.now();
                  }
                  final nextData = coxoData
                      .add(const Duration(days: 7));
                  final nextDataStr = '${nextData.day.toString().padLeft(2, '0')}/${nextData.month.toString().padLeft(2, '0')}/${nextData.year}';
                  final newCoxo = Coxo(
                    coxoId: coxoId,
                    coxoData: coxoDataStr,
                    nextData: nextDataStr,
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
        title: const Text('Acompanhamento', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Atualizar Coxos',
            onPressed: _loadingHttp ? null : () async {
              try {
                await _loadCoxosFromWeb();
              } catch (e) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Erro de conexão'),
                    content: const Text('Não foi possível atualizar os coxos. Verifique sua conexão com a internet.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            if (_loadingHttp) const LinearProgressIndicator(),
            if (_httpMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _httpMessage!,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar Dados'),
                onPressed: () async {
                  try {
                    await _syncCoxos();
                  } catch (e) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Erro de conexão'),
                        content: const Text('Não foi possível sincronizar os dados. Verifique sua conexão com a internet.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
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
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _coxos.isEmpty
                  ? const Center(child: Text('Nenhum registro encontrado.', style: TextStyle(fontSize: 18)))
                  : ListView.builder(
                      itemCount: _coxos.length,
                      itemBuilder: (context, index) {
                        final coxo = _coxos[index];
                        Color? cardColor;
                        try {
                          final partes = coxo.coxoData.split('/');
                          final dataCoxo = DateTime(
                            int.parse(partes[2]),
                            int.parse(partes[1]),
                            int.parse(partes[0]),
                          );
                          final hoje = DateTime.now();
                          final diff = hoje.difference(dataCoxo).inDays;
                          if (diff > 7) {
                            cardColor = Colors.red[100];
                          } else {
                            cardColor = Colors.white;
                          }
                        } catch (_) {
                          cardColor = Colors.white;
                        }
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: cardColor,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text('ID: ${coxo.coxoId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Data: ${coxo.coxoData}', style: const TextStyle(fontSize: 16)),
                                Text('Validade: ${coxo.nextData}', style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.indigo),
                              tooltip: 'Editar',
                              onPressed: () => _addOrEditCoxo(coxo: coxo, index: index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCoxo(),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Adicionar Coxo',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
