import 'dart:convert';
import 'dart:io';

import 'package:apk_agenda_bd_local/service/viacep_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ViaCepService', () {
    test('consulta o CEP sem máscara e preserva os campos e acentos', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://viacep.com.br/ws/01001000/json/',
        );
        return http.Response.bytes(
          utf8.encode(
            json.encode({
              'cep': '01001-000',
              'logradouro': 'Praça da Sé',
              'bairro': 'Sé',
              'localidade': 'São Paulo',
              'uf': 'SP',
              'complemento': 'lado ímpar',
            }),
          ),
          200,
        );
      });
      addTearDown(client.close);

      final dados = await ViaCepService(client: client).buscaCEP('01001-000');

      expect(dados['cep'], '01001-000');
      expect(dados['logradouro'], 'Praça da Sé');
      expect(dados['bairro'], 'Sé');
      expect(dados['localidade'], 'São Paulo');
      expect(dados['uf'], 'SP');
      expect(dados['complemento'], 'lado ímpar');
    });

    test('rejeita um CEP inválido antes de fazer a requisição', () async {
      var requisicoes = 0;
      final client = MockClient((request) async {
        requisicoes++;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final service = ViaCepService(client: client);

      for (final cep in <String?>[null, '', '123', '123456789', '01001A00']) {
        await expectLater(
          service.buscaCEP(cep),
          throwsA(
            isA<FormatException>().having(
              (erro) => erro.message,
              'mensagem',
              'Informe um CEP válido com 8 dígitos.',
            ),
          ),
        );
      }

      expect(requisicoes, 0);
    });

    test('trata CEP inexistente mesmo com HTTP 200', () async {
      final client = MockClient((request) async {
        return http.Response('{"erro": true}', 200);
      });
      addTearDown(client.close);

      await expectLater(
        ViaCepService(client: client).buscaCEP('99999999'),
        throwsA(
          isA<FormatException>().having(
            (erro) => erro.message,
            'mensagem',
            'CEP não encontrado.',
          ),
        ),
      );
    });

    test('trata falha HTTP com mensagem amigável', () async {
      final client = MockClient((request) async {
        return http.Response('indisponível', 503);
      });
      addTearDown(client.close);

      await expectLater(
        ViaCepService(client: client).buscaCEP('01001000'),
        throwsA(
          isA<Exception>().having(
            (erro) => erro.toString(),
            'mensagem',
            contains('Não foi possível consultar o CEP.'),
          ),
        ),
      );
    });

    test('trata falha de conexão', () async {
      final client = MockClient((request) async {
        throw const SocketException('offline');
      });
      addTearDown(client.close);

      await expectLater(
        ViaCepService(client: client).buscaCEP('01001000'),
        throwsA(
          isA<Exception>().having(
            (erro) => erro.toString(),
            'mensagem',
            contains('Sem conexão com a internet.'),
          ),
        ),
      );
    });

    test('trata ClientException de rede', () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline');
      });
      addTearDown(client.close);

      await expectLater(
        ViaCepService(client: client).buscaCEP('01001000'),
        throwsA(
          isA<Exception>().having(
            (erro) => erro.toString(),
            'mensagem',
            contains('Sem conexão com a internet.'),
          ),
        ),
      );
    });

    test('trata JSON malformado', () async {
      final client = MockClient((request) async {
        return http.Response('{invalido', 200);
      });
      addTearDown(client.close);

      await expectLater(
        ViaCepService(client: client).buscaCEP('01001000'),
        throwsA(
          isA<Exception>().having(
            (erro) => erro.toString(),
            'mensagem',
            contains('O serviço de CEP retornou uma resposta inválida.'),
          ),
        ),
      );
    });

    test('rejeita JSON que não contém um objeto de endereço', () async {
      final client = MockClient((request) async {
        return http.Response('[]', 200);
      });
      addTearDown(client.close);

      await expectLater(
        ViaCepService(client: client).buscaCEP('01001000'),
        throwsA(
          isA<Exception>().having(
            (erro) => erro.toString(),
            'mensagem',
            contains('O serviço de CEP retornou uma resposta inválida.'),
          ),
        ),
      );
    });
  });
}
