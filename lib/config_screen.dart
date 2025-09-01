import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _urlController = TextEditingController();
  final StorageService _storageService = StorageService();
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    setState(() => _isLoading = true);
    String? savedUrl = await _storageService.loadUrl();
    if (savedUrl != null) {
      _urlController.text = savedUrl;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveUrl() async {
    if (_urlController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Por favor, insira uma URL.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Salvando...';
    });
    try {
      await _storageService.saveUrl(_urlController.text);
      setState(() {
        _statusMessage = 'URL salva com sucesso!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao salvar: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAndSaveRetiros() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Baixando retiros...';
    });
    try {
      final baseUrl = await _storageService.loadUrl();
      if (baseUrl == null || baseUrl.trim().isEmpty) {
        setState(() {
          _statusMessage = 'Host não configurado. Salve a URL primeiro.';
        });
        return;
      }

      final fullUrl = baseUrl.endsWith('/')
          ? '${baseUrl}read_retiros.php'
          : '$baseUrl/read_retiros.php';

      final resp = await http.get(Uri.parse(fullUrl));
      if (resp.statusCode != 200) {
        setState(() {
          _statusMessage = 'Falha ao baixar (HTTP ${resp.statusCode}).';
        });
        return;
      }

      // Tenta interpretar como JSON; se falhar, salva bruto mesmo
      String toWrite;
      try {
        final decoded = jsonDecode(resp.body);
        toWrite = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        toWrite = resp.body;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/retiros.json');
      await file.writeAsString(toWrite);

      setState(() {
        _statusMessage = 'Retiros salvos em: ${file.path}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erro ao baixar/salvar retiros: $e';
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
      appBar: AppBar(title: const Text('Configuração')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL do servidor'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveUrl,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchAndSaveRetiros,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Baixar Retiros'),
            ),
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
