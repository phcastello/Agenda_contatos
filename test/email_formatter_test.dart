import 'package:apk_agenda_bd_local/utils/email_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata e-mail colado removendo espaços e preservando o cursor', () {
    final result = EmailInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: ' Maria.Silva+Faculdade @ EXEMPLO.COM.BR ',
        selection: TextSelection.collapsed(offset: 21),
      ),
    );
    expect(result.text, 'maria.silva+faculdade@exemplo.com.br');
    expect(result.selection.baseOffset, 20);
  });

  test('não modifica composição em andamento do teclado', () {
    const value = TextEditingValue(
      text: 'MA',
      composing: TextRange(start: 0, end: 2),
    );
    expect(
      EmailInputFormatter().formatEditUpdate(TextEditingValue.empty, value),
      value,
    );
  });

  test('aceita domínios variáveis e rejeita formatos inválidos', () {
    for (final email in [
      'a@b.co',
      'maria.silva+curso@exemplo.com.br',
      'aluno_1@dev-mobile.edu.br',
    ]) {
      expect(isValidEmail(email), true, reason: email);
    }
    for (final email in [
      '',
      'sem-arroba',
      'a@@b.com',
      '@b.com',
      'a@',
      'a@b',
      'a b@c.com',
      '.a@b.com',
      'a.@b.com',
      'a..b@c.com',
      'a@-b.com',
      'a@b-.com',
      'a@b..com',
      'a@b.c',
      'a@b.123',
      'a@b.com\n',
    ]) {
      expect(isValidEmail(email), false, reason: email);
    }
  });
}
