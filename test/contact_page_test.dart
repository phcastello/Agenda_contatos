import 'dart:io';

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:apk_agenda_bd_local/view/contact_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  final helper = ContactHelper();
  late Directory directory;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agenda_widget_');
    await databaseFactory.setDatabasesPath(directory.path);
  });
  tearDown(() async {
    await helper.close();
    await directory.delete(recursive: true);
  });

  testWidgets('bloqueia cadastro com e-mail inválido e mostra mensagem', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ContactPage()));
    await tester.enterText(field('Nome'), 'Maria');
    await tester.enterText(field('Email'), 'maria@');
    await tester.tap(find.byTooltip('Salvar contato'));
    await tester.pumpAndSettle();
    expect(
      find.text('Informe um e-mail válido. Ex.: nome@dominio.com'),
      findsOneWidget,
    );
    expect(find.byType(ContactPage), findsOneWidget);
    expect(await tester.runAsync(helper.getAllContacts), isEmpty);
  });

  testWidgets('bloqueia alteração inválida sem modificar registro salvo', (
    tester,
  ) async {
    final contact = await tester.runAsync(
      () => helper.saveContact(
        Contact(
          name: 'Maria',
          email: 'maria@exemplo.com',
          phone: '',
          img: null,
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: ContactPage(contact: contact)));
    await tester.enterText(field('Nome'), 'Maria alterada');
    await tester.enterText(field('Email'), 'sem-arroba');
    await tester.tap(find.byTooltip('Salvar contato'));
    await tester.pumpAndSettle();
    final stored = await tester.runAsync(() => helper.getContact(contact!.id!));
    expect(stored!.name, 'Maria');
    expect(stored.email, 'maria@exemplo.com');
    expect(contact!.name, 'Maria');
    expect(
      find.text('Informe um e-mail válido. Ex.: nome@dominio.com'),
      findsOneWidget,
    );
  });

  testWidgets('e-mail e telefone usam a formatação ao digitar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContactPage()));
    await tester.enterText(field('Email'), ' ALUNO @ EXEMPLO.COM ');
    await tester.enterText(field('Telefone'), '42999998888');
    expect(
      tester.widget<TextField>(field('Email')).controller!.text,
      'aluno@exemplo.com',
    );
    expect(
      tester.widget<TextField>(field('Telefone')).controller!.text,
      '(42) 99999-8888',
    );
  });

  testWidgets(
    'avatar apresenta câmera e galeria e cancelamento preserva foto',
    (tester) async {
      final contact = Contact(
        name: 'João',
        email: 'joao@exemplo.com',
        phone: '',
        img: null,
      );
      await tester.pumpWidget(MaterialApp(home: ContactPage(contact: contact)));
      await tester.tap(
        find.bySemanticsLabel(
          'Foto do contato. Toque para tirar foto ou selecionar da galeria.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tirar foto'), findsOneWidget);
      expect(find.text('Selecionar da galeria'), findsOneWidget);
      Navigator.of(tester.element(find.text('Tirar foto'))).pop();
      await tester.pumpAndSettle();
      expect(contact.img, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CEP incompleto informa erro sem realizar consulta', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ContactPage()));
    await tester.ensureVisible(field('CEP'));
    await tester.enterText(field('CEP'), '12345');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byTooltip('Consultar CEP'));
    await tester.tap(find.byTooltip('Consultar CEP'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um CEP válido com 8 dígitos.'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('Logradouro')).controller!.text,
      isEmpty,
    );
  });
}
