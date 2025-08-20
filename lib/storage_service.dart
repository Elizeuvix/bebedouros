import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const String _fileName = 'host.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<void> saveUrl(String url) async {
    final file = await _localFile;
    Map<String, String> data = {'host_url': url};
    String jsonString = JsonEncoder.withIndent('  ').convert(data);

    try {
      await file.writeAsString(jsonString);
      print('URL salva com sucesso em: ${file.path}');
    } catch (e) {
      print('Erro ao salvar URL: $e');
      rethrow; // Propaga o erro para que a UI possa lidar com ele
    }
  }

  Future<String?> loadUrl() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        String contents = await file.readAsString();
        Map<String, dynamic> jsonData = jsonDecode(contents);
        return jsonData['host_url'] as String?;
      }
      print('Arquivo $_fileName não encontrado.');
      return null;
    } catch (e) {
      print('Erro ao carregar URL: $e');
      return null;
    }
  }
}