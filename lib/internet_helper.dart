import 'package:connectivity_plus/connectivity_plus.dart';
Future<bool> checkInternet() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  print('DEBUG Connectivity result: $connectivityResult');
  return connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi;
}
