import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/common/json_store.dart';

void main() {
  test(
    'FileJsonStore sérialise les écritures concurrentes d’un même document',
    () async {
      final root = await Directory.systemTemp.createTemp('juzreviz_json_store');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = FileJsonStore(root: root);
      final payload = 'x' * 20000;

      await Future.wait([
        for (var revision = 0; revision < 20; revision++)
          store.write('state', {'revision': revision, 'payload': payload}),
      ]);

      final persisted = await store.read('state');
      expect(persisted?['revision'], 19);
      expect(File('${root.path}/state.json.tmp').existsSync(), isFalse);
    },
  );
}
