import 'package:flutter/material.dart';
import 'storage_service.dart';

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
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
