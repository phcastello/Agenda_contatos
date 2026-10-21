import 'dart:io';

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/main.dart' as app;
import 'package:apk_agenda_bd_local/service/contact_photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final helper = ContactHelper();
  late Directory testDirectory;
  late String originalDatabasePath;

  setUpAll(() async {
    originalDatabasePath = await getDatabasesPath();
    testDirectory = await Directory(
      (await getTemporaryDirectory()).path,
    ).createTemp('agenda_integration_');
    await databaseFactory.setDatabasesPath(testDirectory.path);
  });

  tearDownAll(() async {
    await helper.close();
    await databaseFactory.setDatabasesPath(originalDatabasePath);
    await testDirectory.delete(recursive: true);
  });

  testWidgets(
    'cadastro, CEP real, persistência, edição e exclusão no Android',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Novo contato'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nome'), 'Maria da Silva');
      await tester.enterText(field('Email'), 'email-invalido');
      await tester.tap(find.byTooltip('Salvar contato'));
      await tester.pumpAndSettle();
      expect(await helper.getAllContacts(), isEmpty);
      expect(
        find.text('Informe um e-mail válido. Ex.: nome@dominio.com'),
        findsOneWidget,
      );

      await tester.enterText(field('Email'), ' MARIA @ EXEMPLO.COM ');
      await tester.enterText(field('Telefone'), '42999998888');
      await tester.ensureVisible(field('CEP'));
      await tester.enterText(field('CEP'), '01001000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (tester.widget<TextField>(field('Cidade')).controller!.text ==
            'São Paulo') {
          break;
        }
      }
      expect(
        tester.widget<TextField>(field('CEP')).controller!.text,
        '01001-000',
      );
      expect(
        tester.widget<TextField>(field('Logradouro')).controller!.text,
        'Praça da Sé',
      );
      expect(tester.widget<TextField>(field('Bairro')).controller!.text, 'Sé');
      expect(
        tester.widget<TextField>(field('Cidade')).controller!.text,
        'São Paulo',
      );
      expect(
        tester.widget<TextField>(field('Estado/UF')).controller!.text,
        'SP',
      );
      await tester.ensureVisible(field('Número'));
      await tester.enterText(field('Número'), '123');
      await tester.ensureVisible(field('Complemento'));
      await tester.enterText(field('Complemento'), 'Apartamento 42');
      await tester.tap(find.byTooltip('Salvar contato'));
      await tester.pumpAndSettle();
      expect(find.text('Agenda de Contatos'), findsOneWidget);
      await helper.close();
      var saved = (await helper.getAllContacts()).single;
      expect(saved.email, 'maria@exemplo.com');
      expect(saved.phone, '(42) 99999-8888');
      expect(saved.cep, '01001-000');
      expect(saved.logradouro, 'Praça da Sé');
      expect(saved.numero, '123');
      expect(saved.complemento, 'Apartamento 42');

      // Exercita armazenamento permanente usando um arquivo temporário real.
      final bytes = await rootBundle.load('assets/imgs/image.png');
      final temporaryPhoto = File(path.join(testDirectory.path, 'camera.png'));
      await temporaryPhoto.writeAsBytes(bytes.buffer.asUint8List());
      saved.img = await ContactPhotoService().savePhoto(temporaryPhoto.path);
      await temporaryPhoto.delete();
      expect(await File(saved.img!).exists(), true);
      await helper.updateContact(saved);
      await helper.close();
      saved = (await helper.getContact(saved.id!))!;
      expect(await File(saved.img!).exists(), true);
      await tester.pumpWidget(const SizedBox.shrink());
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maria da Silva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Email'), 'maria@');
      await tester.tap(find.byTooltip('Salvar contato'));
      await tester.pumpAndSettle();
      expect((await helper.getContact(saved.id!))!.email, 'maria@exemplo.com');
      await tester.enterText(field('Email'), 'novo@exemplo.com.br');
      await tester.enterText(field('Nome'), 'Maria atualizada');
      await tester.tap(find.byTooltip('Salvar contato'));
      await tester.pumpAndSettle();
      expect(find.text('Maria atualizada'), findsOneWidget);
      expect(
        (await helper.getAllContacts()).single.email,
        'novo@exemplo.com.br',
      );
      expect((await helper.getContact(saved.id!))!.img, saved.img);
      await tester.tap(find.text('Maria atualizada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum contato cadastrado.'), findsOneWidget);
      expect(await helper.getAllContacts(), isEmpty);
      await File(saved.img!).delete();
      expect(tester.takeException(), isNull);
    },
  );
}
