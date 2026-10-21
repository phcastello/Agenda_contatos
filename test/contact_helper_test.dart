import 'dart:io';

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Contact', () {
    test('lê registros da aula sem colunas de endereço', () {
      final contact = Contact.fromMap({
        'idColumn': 8,
        'nameColumn': "João D'Ávila",
        'emailColumn': 'joao@email.com',
        'phoneColumn': '(42) 99999-8888',
        'imgColumn': null,
      });

      expect(contact.id, 8);
      expect(contact.name, "João D'Ávila");
      expect(contact.email, 'joao@email.com');
      expect(contact.phone, '(42) 99999-8888');
      expect(contact.img, isNull);
      expect(contact.cep, isEmpty);
      expect(contact.logradouro, isEmpty);
      expect(contact.bairro, isEmpty);
      expect(contact.cidade, isEmpty);
      expect(contact.uf, isEmpty);
      expect(contact.numero, isEmpty);
      expect(contact.complemento, isEmpty);
    });

    test('mapeia endereço e foto, incluindo ID somente após salvar', () {
      final contact = Contact(
        name: 'Maria da Silva',
        email: 'maria@email.com',
        phone: '(11) 99999-8888',
        img: '/documentos/fotos/maria.jpg',
        cep: '01001-000',
        logradouro: 'Praça da Sé',
        bairro: 'Sé',
        cidade: 'São Paulo',
        uf: 'SP',
        numero: '123A',
        complemento: 'Apartamento 42',
      );

      final expected = <String, dynamic>{
        'nameColumn': 'Maria da Silva',
        'emailColumn': 'maria@email.com',
        'phoneColumn': '(11) 99999-8888',
        'imgColumn': '/documentos/fotos/maria.jpg',
        'cepColumn': '01001-000',
        'logradouroColumn': 'Praça da Sé',
        'bairroColumn': 'Sé',
        'cidadeColumn': 'São Paulo',
        'ufColumn': 'SP',
        'numeroColumn': '123A',
        'complementoColumn': 'Apartamento 42',
      };
      expect(contact.toMap(), expected);

      contact.id = 31;
      expected['idColumn'] = 31;
      expect(contact.toMap(), expected);
      expect(Contact.fromMap(expected).toMap(), expected);
    });
  });

  group('ContactHelper em arquivo SQLite isolado', () {
    final helper = ContactHelper();
    late Directory testDirectory;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      await helper.close();
      testDirectory = await Directory.systemTemp.createTemp('agenda_db_test_');
      await databaseFactory.setDatabasesPath(testDirectory.path);
    });

    tearDown(() async {
      await helper.close();
      await testDirectory.delete(recursive: true);
    });

    test('persiste, altera e exclui somente o contato selecionado', () async {
      final contact = await helper.saveContact(
        Contact(
          name: "João D'Ávila",
          email: 'joao@email.com',
          phone: '(42) 99999-8888',
          img: join(testDirectory.path, 'foto-permanente.jpg'),
          cep: '84010-000',
          logradouro: 'Rua Balduíno Taques',
          bairro: 'Centro',
          cidade: 'Ponta Grossa',
          uf: 'PR',
          numero: '100',
          complemento: 'Casa dos fundos',
        ),
      );
      final other = await helper.saveContact(
        Contact(
          name: 'Ana',
          email: 'ana@email.com',
          phone: '(42) 98888-7777',
          img: null,
        ),
      );
      expect(contact.id, isNotNull);
      expect(other.id, isNot(contact.id));
      expect(
        await File(join(testDirectory.path, 'contactsDB.db')).exists(),
        true,
      );

      // Reabrir o arquivo comprova a persistência além da lista em memória.
      await helper.close();
      final loaded = (await helper.getContact(contact.id!))!;
      expect(loaded.toMap(), contact.toMap());
      expect((await helper.getAllContacts()).length, 2);

      loaded.name = 'João atualizado';
      loaded.email = 'novo@email.com';
      loaded.phone = '(11) 97777-6666';
      loaded.img = join(testDirectory.path, 'nova-foto.jpg');
      loaded.cep = '01001-000';
      loaded.logradouro = 'Praça da Sé';
      loaded.bairro = 'Sé';
      loaded.cidade = 'São Paulo';
      loaded.uf = 'SP';
      loaded.numero = '55B';
      loaded.complemento = 'Sala 2';
      expect(await helper.updateContact(loaded), 1);

      await helper.close();
      expect((await helper.getContact(contact.id!))!.toMap(), loaded.toMap());
      expect((await helper.getContact(other.id!))!.toMap(), other.toMap());

      expect(await helper.deleteContact(contact.id!), 1);
      await helper.close();
      expect(await helper.getContact(contact.id!), isNull);
      final remaining = await helper.getAllContacts();
      expect(remaining, hasLength(1));
      expect(remaining.single.toMap(), other.toMap());
    });

    test(
      'migra a versão 1 preservando IDs, dados e caminhos de fotos',
      () async {
        final originalRows = <Map<String, dynamic>>[
          {
            'idColumn': 7,
            'nameColumn': "João D'Ávila",
            'emailColumn': 'joao@email.com',
            'phoneColumn': '(42) 99999-8888',
            'imgColumn': '/fotos/joao.jpg',
          },
          {
            'idColumn': 19,
            'nameColumn': 'Ana',
            'emailColumn': 'ana@email.com',
            'phoneColumn': '(42) 98888-7777',
            'imgColumn': null,
          },
        ];
        final oldDb = await openDatabase(
          join(testDirectory.path, 'contactsDB.db'),
          version: 1,
          onCreate: (db, version) async {
            // Esquema original das aulas, antes dos campos pedidos na atividade.
            await db.execute(
              'CREATE TABLE contactTable('
              'idColumn INTEGER PRIMARY KEY, '
              'nameColumn TEXT, '
              'emailColumn TEXT, '
              'phoneColumn TEXT, '
              'imgColumn TEXT)',
            );
          },
        );
        for (final row in originalRows) {
          await oldDb.insert('contactTable', row);
        }
        await oldDb.close();

        final migrated = await helper.getAllContacts();
        expect(migrated, hasLength(2));
        expect(await (await helper.db).getVersion(), 2);
        for (final original in originalRows) {
          final loaded = migrated.singleWhere(
            (contact) => contact.id == original['idColumn'],
          );
          expect(loaded.toMap(), {
            ...original,
            'cepColumn': '',
            'logradouroColumn': '',
            'bairroColumn': '',
            'cidadeColumn': '',
            'ufColumn': '',
            'numeroColumn': '',
            'complementoColumn': '',
          });
        }

        final edited = migrated.singleWhere((contact) => contact.id == 7);
        edited.cep = '01001-000';
        edited.logradouro = 'Praça da Sé';
        edited.bairro = 'Sé';
        edited.cidade = 'São Paulo';
        edited.uf = 'SP';
        edited.numero = '42';
        edited.complemento = 'Apartamento 3';
        expect(await helper.updateContact(edited), 1);
        await helper.close();
        expect((await helper.getContact(7))!.toMap(), edited.toMap());
        expect((await helper.getContact(19))!.name, 'Ana');
      },
    );
  });
}
