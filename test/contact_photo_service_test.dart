import 'dart:convert';
import 'dart:io';

import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:apk_agenda_bd_local/service/contact_photo_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = ContactPhotoService();
  final imageBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6ioAAAAASUVORK5CYII=',
  );
  late Directory testDirectory;
  late Directory documents;
  late Directory cache;

  setUp(() async {
    testDirectory = await Directory.systemTemp.createTemp('agenda_photo_test_');
    documents = await Directory(
      path.join(testDirectory.path, 'documents'),
    ).create();
    cache = await Directory(path.join(testDirectory.path, 'cache')).create();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documents.path;
      }
      throw MissingPluginException('Método inesperado: ${call.method}');
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await testDirectory.delete(recursive: true);
  });

  test(
    'a foto permanece disponível após a origem do cache ser removida',
    () async {
      final source = await File(
        path.join(cache.path, 'camera.png'),
      ).writeAsBytes(imageBytes, flush: true);

      final savedPath = await service.savePhoto(source.path);
      expect(savedPath, isNot(source.path));
      expect(path.dirname(savedPath), path.join(documents.path, 'photos'));
      expect(path.extension(savedPath), '.png');
      expect(await File(savedPath).readAsBytes(), imageBytes);

      // Simula a limpeza do cache feita pelo Android depois da captura.
      await cache.delete(recursive: true);
      expect(await source.exists(), false);
      expect(await File(savedPath).exists(), true);
      expect(await File(savedPath).readAsBytes(), imageBytes);
    },
  );

  test('reaproveita uma foto já armazenada sem criar outra cópia', () async {
    final source = await File(
      path.join(cache.path, 'galeria.png'),
    ).writeAsBytes(imageBytes, flush: true);
    final permanentPath = await service.savePhoto(source.path);

    final reusedPath = await service.savePhoto(permanentPath);

    expect(reusedPath, permanentPath);
    final photos = await Directory(
      path.join(documents.path, 'photos'),
    ).list().toList();
    expect(photos, hasLength(1));
    expect(photos.single.path, permanentPath);
    expect(await File(reusedPath).readAsBytes(), imageBytes);
  });

  test(
    'recupera o rascunho completo de uma nova instância e o limpa',
    () async {
      expect(await service.recoverDraft(), isNull);
      final contact = Contact(
        id: 23,
        name: "João D'Ávila",
        email: 'joao@email.com',
        phone: '(42) 99999-8888',
        img: path.join(cache.path, 'foto-anterior.png'),
        cep: '01001-000',
        logradouro: 'Praça da Sé',
        bairro: 'Sé',
        cidade: 'São Paulo',
        uf: 'SP',
        numero: '55B',
        complemento: 'Apartamento 42',
      );

      await service.saveDraft(contact);
      final reopenedService = ContactPhotoService();
      final recovered = await reopenedService.recoverDraft();
      expect(recovered, isNotNull);
      expect(recovered!.toMap(), contact.toMap());

      await reopenedService.clearDraft();
      expect(await service.recoverDraft(), isNull);
      // Limpar novamente deve ser seguro mesmo sem haver rascunho.
      await service.clearDraft();
      expect(await documents.list().toList(), isEmpty);
    },
  );

  test('informa quando a foto escolhida deixou de existir', () async {
    await expectLater(
      service.savePhoto(path.join(cache.path, 'inexistente.png')),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'mensagem',
          contains('A foto não está disponível. Selecione outra imagem.'),
        ),
      ),
    );
    expect(await documents.list().toList(), isEmpty);
  });
}
