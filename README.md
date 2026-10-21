# Agenda de Contatos

Aplicativo Android da atividade, implementado em Flutter com SQLite e baseado nos materiais de `Aulas.zip`.

## Baixar o aplicativo

**[Baixar o APK da Agenda de Contatos](https://github.com/phcastello/Agenda_contatos/releases/download/v1.0.0/agenda-contatos.apk)**

O APK completo está hospedado na [Release 1.0.0](https://github.com/phcastello/Agenda_contatos/releases/tag/v1.0.0). O link pode ser enviado diretamente para a entrega da atividade, sem anexar o arquivo à plataforma com limite de 20 MB. A versão é universal, com suporte a ARM32, ARM64 e x86_64, e requer Android 7.0 ou superior.

Também estão disponíveis o [código-fonte em ZIP](https://github.com/phcastello/Agenda_contatos/releases/download/v1.0.0/agenda-contatos-codigo-fonte.zip) e os [códigos SHA-256 para conferir os arquivos](https://github.com/phcastello/Agenda_contatos/releases/download/v1.0.0/SHA256SUMS.txt).

## Executar e gerar o APK

Com Flutter e o SDK Android instalados:

```sh
flutter pub get
flutter run
flutter build apk --release
```

O APK é gerado em `build/app/outputs/flutter-apk/app-release.apk`. A cópia para entrega fica em `entrega/agenda-contatos.apk` quando a compilação é concluída.

O arquivo `entrega/agenda-contatos-codigo-fonte.zip` contém o projeto e os testes, sem os arquivos temporários das aulas e da compilação. O APK não contém contatos de demonstração.

## Implementação das aulas

A base segue **Agenda de Contatos com Flutter e SQLite**: `Contact` com `fromMap`/`toMap` e constantes de coluna (p. 6–11), `ContactHelper` singleton e CRUD (p. 12–18), `HomePage` e `ContactPage` com `StatefulWidget`/`setState`, navegação com retorno do contato e atualização da lista (p. 19–35). Mantidos os cartões, avatares de 80/140, barra azul, botões flutuantes, menu Ligar/Editar/Excluir, ordenação A–Z/Z–A e máscara de telefone (p. 24–44).

A integração de CEP segue o padrão da apresentação **Consumo de API com Flutter – Invertexto**: serviço em `lib/service/`, método `buscaCEP`, `http.get`, `Uri.parse`, JSON e tratamento de falhas. Foi usado o [ViaCEP](https://viacep.com.br/), gratuito e sem token. As sete aulas gerais também foram conferidas para manter os recursos e o estilo ensinados: Dart, classes, coleções, funções, widgets, assets e estado local.

Não foi acrescentada uma arquitetura de gerenciamento de estado externa. Os exemplos intermediários de teste do banco e as propostas futuras de nuvem não fazem parte da versão final da atividade.

## Alterações da atividade

- **E-mail:** teclado adequado, remoção de espaços e conversão para minúsculas durante a digitação, domínio livre e validação antes de cadastrar ou alterar. Um e-mail inválido mostra erro no campo e mensagem, sem gravar o contato. Como o tamanho do e-mail varia, a formatação não usa uma máscara fixa como a do telefone.
- **Foto:** toque no avatar e escolha **Tirar foto** ou **Selecionar da galeria**. Ao salvar, a imagem é copiada para a pasta permanente do aplicativo e seu caminho é armazenado no SQLite. A lista e a edição exibem a foto. Há recuperação de foto e rascunho caso o Android encerre o aplicativo enquanto a câmera estiver aberta.
- **Endereço:** ao completar os oito dígitos do CEP, a consulta preenche logradouro, bairro, cidade, UF e o complemento retornado. O botão de busca permite consultar novamente. **Número é informado manualmente**, pois a API não conhece o imóvel. O complemento pode ser alterado. Todos os campos são persistidos e exibidos junto ao contato. CEP inexistente e falhas de conexão apresentam mensagens. Sem rede, o endereço pode ser preenchido manualmente.
- **Banco:** a versão 2 acrescenta as colunas do endereço. A migração preserva contatos e fotos da tabela original da aula.

A consulta de CEP precisa de internet; as operações de contatos e a exibição de fotos salvas funcionam localmente. A câmera e a galeria são abertas pelo `image_picker`, sem solicitar acesso amplo ao armazenamento. O botão Ligar abre o discador do aparelho.

## Verificação

```sh
flutter analyze
flutter test
flutter test integration_test/agenda_test.dart -d <dispositivo-android>
```

Os testes cobrem validação/formatação de e-mail, bloqueio de cadastro e alteração inválidos, máscaras, opções de foto, CRUD, persistência física, migração do banco e respostas de sucesso/erro do ViaCEP. O teste de integração usa um banco temporário isolado e consulta um CEP real, portanto precisa de internet.

Verificação realizada: análise sem avisos, 24 testes automatizados aprovados e teste de integração Android aprovado (cadastro, CEP real, persistência, edição e exclusão). O APK release também foi instalado no emulador: captura pela câmera, associação ao contato e exibição da foto após encerrar e reabrir o aplicativo foram conferidas. O seletor nativo da galeria abriu corretamente. A assinatura do APK foi verificada.
