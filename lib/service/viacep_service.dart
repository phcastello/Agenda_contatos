import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ViaCepService {
  // O cliente opcional permite testar a consulta sem acessar a internet.
  // Quem fornece um cliente também é responsável por fechá-lo.
  ViaCepService({this.client});

  final http.Client? client;

  Future<Map<String, dynamic>> buscaCEP(String? valor) async {
    final cep = (valor ?? '').replaceAll(RegExp(r'[-\s]'), '');
    if (!RegExp(r'^\d{8}$').hasMatch(cep)) {
      throw const FormatException('Informe um CEP válido com 8 dígitos.');
    }

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await (client?.get(uri) ?? http.get(uri)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        throw Exception('Não foi possível consultar o CEP. Tente novamente.');
      }

      final dynamic dados;
      try {
        dados = json.decode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw Exception('O serviço de CEP retornou uma resposta inválida.');
      }

      if (dados is! Map<String, dynamic>) {
        throw Exception('O serviço de CEP retornou uma resposta inválida.');
      }
      if (dados['erro'] == true || dados['erro'] == 'true') {
        throw const FormatException('CEP não encontrado.');
      }

      return dados;
    } on SocketException {
      throw Exception('Sem conexão com a internet.');
    } on http.ClientException {
      throw Exception('Sem conexão com a internet.');
    } on TimeoutException {
      throw Exception('A consulta demorou demais. Tente novamente.');
    }
  }
}
