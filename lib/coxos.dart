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
  final String userName;
  final String retiro;

  Coxo({required this.coxoId, required this.coxoData, required this.nextData, required this.userName, required this.retiro});

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
      userName: json['usuario'] ?? '',
      retiro: (json['retiro'] ?? json['localidade'] ?? '').toString(),
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
  List<String> _retiros = [];
  String _selectedRetiro = '';

  @override
  void initState() {
    super.initState();
    _initRetirosAndCoxos();
    _checkSyncAvailable();
  }

  Future<void> _initRetirosAndCoxos() async {
    await _loadRetirosList();
    _selectedRetiro = await _loadRetiroSelecionado();
    await _loadCoxos();
  }

  Future<void> _checkSyncAvailable() async {
    final hasInternet = await checkInternet();
    setState(() {
      // Apenas mantém o estado atualizado; no futuro pode habilitar/desabilitar botões
      _syncing = _syncing && hasInternet;
    });
  }

  Future<void> _syncCoxos() async {
    final directory = await getApplicationDocumentsDirectory();
    final userFile = File('${directory.path}/user.json');
    if (await userFile.exists()) {
      final userContent = await userFile.readAsString();
      final userJson = jsonDecode(userContent);
      // usuário carregado se necessário para logs futuros
      final _ = userJson['nome'] ?? '';
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
            'usuarioPost': item['usuario'] ?? '',
    'localidadePost': item['retiro'] ?? '',
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

        // Envia histórico
        final historicoFile = File('${directory.path}/historico.json');
        if (await historicoFile.exists()) {
          final histContent = await historicoFile.readAsString();
          if (histContent.isNotEmpty) {
            final historicoList = jsonDecode(histContent);
            for (var hist in historicoList) {
              await _saveHistorico(
                hist['coxo_id'] ?? '',
                hist['data_hist'] ?? '',
                hist['usuario'] ?? '',
                hist['retiro'] ?? '',
              );
            }
            await historicoFile.writeAsString('[]'); // Limpa histórico após envio
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

  // Normaliza strings para comparação: trim, minúsculas e sem acentos
  String _normalize(String s) {
    String out = s.trim().toLowerCase();
    const from = 'áàãâäÁÀÃÂÄéèêëÉÈÊËíìîïÍÌÎÏóòõôöÓÒÕÔÖúùûüÚÙÛÜçÇ';
    const to   = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcC';
    for (int i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  Future<void> _saveRetiroSelecionado(String r) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/retiro_selected.json');
      await file.writeAsString(jsonEncode({'retiro': r}));
    } catch (_) {}
  }

  Future<void> _loadRetirosList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/retiros.json');
      if (!await file.exists()) {
        setState(() => _retiros = []);
        return;
      }
      final content = await file.readAsString();
      dynamic data = jsonDecode(content);
      List<String> values = [];
      if (data is Map && data['data'] is List) {
        data = data['data'];
      }
      if (data is List) {
        for (final item in data) {
          if (item is String) {
            values.add(item);
          } else if (item is Map) {
            final v = (item['localidade'] ?? item['retiro'] ?? item['nome'] ?? item['id'] ?? item['descricao'])?.toString();
            if (v != null && v.isNotEmpty) values.add(v);
          }
        }
      }
      values = values.toSet().toList()..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() => _retiros = values);
    } catch (_) {
      setState(() => _retiros = []);
    }
  }

  // Lê o retiro selecionado do arquivo 'retiro_selected.json' (se existir)
  Future<String> _loadRetiroSelecionado() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/retiro_selected.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        if (data is Map) {
          final v = data['retiro'] ?? data['nome'] ?? data['id'] ?? '';
          return v?.toString() ?? '';
        }
        if (data is String) return data;
      }
    } catch (_) {}
    return '';
  }

  Future<void> _loadCoxos() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
  final selectedRetiro = _selectedRetiro.isNotEmpty ? _selectedRetiro : await _loadRetiroSelecionado();
  final selNorm = _normalize(selectedRetiro);
        final List<dynamic> filtered = selNorm.isEmpty
            ? jsonList
            : jsonList.where((e) {
                try {
                  if (e is Map) {
                    final r = (e['retiro']?.toString() ?? '');
                    return _normalize(r) == selNorm;
                  }
                } catch (_) {}
                return false;
              }).toList();
        setState(() {
          _coxos = filtered.map((e) => Coxo.fromJson(e)).toList();
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
            'usuario': c.userName,
            'retiro': c.retiro,
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
  // Carrega o retiro selecionado para filtrar/etiquetar os registros
  final retiroDataStr = await _loadRetiroSelecionado();

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
          final usuario = item['usuario'] ?? '';
          final localidade = (item['localidade'] ?? retiroDataStr).toString();
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
          // Marca cada item com o retiro selecionado para permitir filtro local
          coxosToSave.add({
            'coxo_id': coxoId,
            'retiro': localidade,
            'coxo_data': coxoData,
            'next_data': nextData,
            'usuario': usuario,
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
  String dataAtual = '';
  final hoje = DateTime.now();
  dataAtual = '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
  // Sempre preencher a data com a data atual ao abrir para novo/editar
  final dataController = TextEditingController(text: dataAtual);
    await _loadRetirosList();
    String initialRetiro = (coxo?.retiro ?? _selectedRetiro).trim();
    if (initialRetiro.isEmpty) {
      initialRetiro = (await _loadRetiroSelecionado()).trim();
    }
    // Opções do dropdown (itens aparados e não vazios)
    List<String> retOptions = _retiros.map((r) => r.trim()).where((r) => r.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // Seleção inicial deve ser exatamente um item de retOptions; se não houver, insere-o
    String currentRetiro;
    if (initialRetiro.isNotEmpty) {
      final idx = retOptions.indexWhere((r) => _normalize(r) == _normalize(initialRetiro));
      if (idx >= 0) {
        currentRetiro = retOptions[idx];
      } else {
        retOptions.insert(0, initialRetiro);
        currentRetiro = initialRetiro;
      }
    } else {
      currentRetiro = '';
    }
    final localidadeController = TextEditingController(text: currentRetiro.isNotEmpty ? currentRetiro : initialRetiro);
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (contextSB, setStateSB) {
            return AlertDialog(
              title: Text(coxo == null ? 'Novo Bebedouro' : 'Editar Bebedouro'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Localidade (Retiro)
          if (retOptions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: currentRetiro.isNotEmpty ? currentRetiro : null,
            items: retOptions
                            .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (val) => setStateSB(() {
                          currentRetiro = val?.trim() ?? '';
                          localidadeController.text = currentRetiro;
                        }),
                        decoration: const InputDecoration(labelText: 'Localidade'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Selecione a localidade' : null,
                      )
                    else
                      TextFormField(
                        controller: localidadeController,
                        decoration: const InputDecoration(labelText: 'Localidade'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Informe a localidade' : null,
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'Coxo ID'),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o ID' : null,
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
                  final selectedRetiro = _retiros.isNotEmpty ? currentRetiro : localidadeController.text.trim();
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
                  // Lê nome do usuário salvo em user.json
                  String usuarioNome = '';
                  final directory = await getApplicationDocumentsDirectory();
                  final userFile = File('${directory.path}/user.json');
                  if (await userFile.exists()) {
                    final userContent = await userFile.readAsString();
                    final userJson = jsonDecode(userContent);
                    usuarioNome = userJson['nome'] ?? '';
                  }
                  final newCoxo = Coxo(
                    coxoId: coxoId,
                    coxoData: coxoDataStr,
                    nextData: nextDataStr,
                    userName: usuarioNome,
                    retiro: selectedRetiro,
                  );
                  setState(() {
                    if (index != null) {
                      _coxos[index] = newCoxo;
                    } else {
                      _coxos.add(newCoxo);
                    }
                  });
                    // Adiciona ao historico.json
                    final historicoFile = File('${directory.path}/historico.json');
                    List<dynamic> historicoList = [];
                    if (await historicoFile.exists()) {
                      final histContent = await historicoFile.readAsString();
                      if (histContent.isNotEmpty) {
                        historicoList = jsonDecode(histContent);
                      }
                    }
                    historicoList.add({
                      'coxo_id': coxoId,
                      'retiro': selectedRetiro,
                      'data_hist': coxoDataStr,
                      'usuario': usuarioNome,
                    });
                    await historicoFile.writeAsString(jsonEncode(historicoList));
                  await _saveCoxos();
                  // Recarrega a lista aplicando o filtro de localidade atual
                  await _loadCoxos();
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
            );
          },
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
                // Reload lista de retiros, caso backend atualize localidades
                await _loadRetirosList();
                // Recarrega lista filtrada
                await _loadCoxos();
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
            // Filtro por Retiro no topo da página
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  const Text('Retiro:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: (_selectedRetiro.isEmpty ? 'Todos' : _selectedRetiro),
                          items: ['Todos', ..._retiros]
                              .map(
                                (r) => DropdownMenuItem<String>(
                                  value: r,
                                  child: Text(r),
                                ),
                              )
                              .toList(),
                          onChanged: (val) async {
                            if (val == null) return;
                            final newSel = val == 'Todos' ? '' : val;
                            setState(() => _selectedRetiro = newSel);
                            await _saveRetiroSelecionado(newSel);
                            await _loadCoxos();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
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
                        // Calcula validade (data + 7 dias) para exibição
                        String validadeStr;
                        try {
                          final partes = coxo.coxoData.split('/');
                          final dataBase = DateTime(
                            int.parse(partes[2]),
                            int.parse(partes[1]),
                            int.parse(partes[0]),
                          );
                          final validade = dataBase.add(const Duration(days: 7));
                          validadeStr = '${validade.day.toString().padLeft(2, '0')}/${validade.month.toString().padLeft(2, '0')}/${validade.year}';
                        } catch (_) {
                          validadeStr = coxo.nextData; // fallback
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
                            isThreeLine: true,
                            title: Text('Pasto ID: ${coxo.coxoId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Localidade: ${coxo.retiro}', style: const TextStyle(fontSize: 16)),
                                Text('Data: ${coxo.coxoData}', style: const TextStyle(fontSize: 16)),
                                Text('Validade: $validadeStr', style: const TextStyle(fontSize: 16)),
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

  Future<void> _saveHistorico(String coxo_id, String data_hist, String user, String retiro) async {
    // Lê host salvo em host.json
    final directory = await getApplicationDocumentsDirectory();
    final hostFile = File('${directory.path}/host.json');
    String hostUrl = '';
    if (await hostFile.exists()) {
      final hostContent = await hostFile.readAsString();
      final hostJson = jsonDecode(hostContent);
      hostUrl = hostJson['host_url'] ?? '';
    }

    final url = Uri.parse('$hostUrl/insert_hist.php');
    final body = {
      'coxo_idPost': coxo_id,
      'data_histPost': data_hist,
      'usuarioPost': user,
      'localidadePost': retiro,
    };
    http.post(url, body: body).then((response) {
      if (response.statusCode == 200) {
        // Sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Histórico salvo com sucesso!')),
        );
      } else {
        // Erro
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar histórico: ${response.body}')),
        );
      }
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $error')),
      );
    });
  }
}
