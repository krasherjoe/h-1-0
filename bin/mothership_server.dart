import 'dart:io';

import 'package:h_1/mothership/config.dart';
import 'package:h_1/mothership/data_store.dart';
import 'package:h_1/mothership/server.dart';

Future<void> main(List<String> args) async {
  final config = MothershipConfig.fromEnv();
  final dataStore = MothershipDataStore(config.dataDirectory);
  await dataStore.init();
  final server = MothershipServer(config: config, dataStore: dataStore);
  final httpServer = await server.start();
  stdout.writeln('Mothership listening on http://${config.host}:${config.port}');
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('Stopping mothership...');
    await httpServer.close();
    exit(0);
  });
}
