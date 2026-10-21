import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:apk_agenda_bd_local/service/contact_photo_service.dart';
import 'package:apk_agenda_bd_local/service/viacep_service.dart';
import 'package:apk_agenda_bd_local/utils/email_formatter.dart';

class ContactPage extends StatefulWidget {
  final Contact? contact;
  final bool recoveredDraft;
  const ContactPage({super.key, this.contact, this.recoveredDraft = false});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  late Contact _editContact;
  bool _userEdited = false;
  bool _saving = false;
  bool _selectingImage = false;
  bool _loadingCep = false;
  String? _emailError;
  String? _cepError;
  String? _cepMessage;
  int _cepRequest = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();

  final ContactHelper _helper = ContactHelper();
  final ImagePicker _picker = ImagePicker();
  final ViaCepService _cepService = ViaCepService();
  final ContactPhotoService _photoService = ContactPhotoService();
  final phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final cepMask = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _userEdited = widget.recoveredDraft;
    // Uma cópia evita alterar o contato da lista antes de tocar em Salvar.
    _editContact = widget.contact == null
        ? Contact(name: '', email: '', phone: '', img: null)
        : Contact.fromMap(widget.contact!.toMap());
    _nameController.text = _editContact.name;
    _emailController.text = _editContact.email;
    _phoneController.value = phoneMask.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: _editContact.phone),
    );
    _cepController.value = cepMask.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: _editContact.cep),
    );
    _logradouroController.text = _editContact.logradouro;
    _bairroController.text = _editContact.bairro;
    _cidadeController.text = _editContact.cidade;
    _ufController.text = _editContact.uf;
    _numeroController.text = _editContact.numero;
    _complementoController.text = _editContact.complemento;
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _emailController,
      _phoneController,
      _cepController,
      _logradouroController,
      _bairroController,
      _cidadeController,
      _ufController,
      _numeroController,
      _complementoController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _updateContact() {
    _editContact.name = _nameController.text.trim();
    _editContact.email = _emailController.text.trim().toLowerCase();
    _editContact.phone = _phoneController.text;
    _editContact.cep = _cepController.text;
    _editContact.logradouro = _logradouroController.text.trim();
    _editContact.bairro = _bairroController.text.trim();
    _editContact.cidade = _cidadeController.text.trim();
    _editContact.uf = _ufController.text.trim().toUpperCase();
    _editContact.numero = _numeroController.text.trim();
    _editContact.complemento = _complementoController.text.trim();
  }

  Future<void> _selectImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Selecionar da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _selectingImage = true);
    try {
      _updateContact();
      // O Android pode encerrar a Activity enquanto a câmera está aberta.
      await _photoService.saveDraft(_editContact);
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      await _photoService.clearDraft();
      if (image != null && mounted) {
        setState(() {
          _editContact.img = image.path;
          _userEdited = true;
        });
      }
    } on PlatformException {
      _message(
        'Não foi possível abrir a câmera ou galeria. Verifique as permissões do dispositivo.',
      );
    } catch (_) {
      _message('Não foi possível selecionar a foto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _selectingImage = false);
    }
  }

  void _cepChanged(String text) {
    _userEdited = true;
    _cepRequest++;
    // Não deixar endereço de um CEP anterior associado ao novo CEP.
    _logradouroController.clear();
    _bairroController.clear();
    _cidadeController.clear();
    _ufController.clear();
    _complementoController.clear();
    setState(() {
      _loadingCep = false;
      _cepError = null;
      _cepMessage = null;
    });
    if (text.replaceAll(RegExp(r'\D'), '').length == 8) _searchCep();
  }

  Future<void> _searchCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      setState(() => _cepError = 'Informe um CEP válido com 8 dígitos.');
      return;
    }
    final request = ++_cepRequest;
    setState(() {
      _loadingCep = true;
      _cepError = null;
      _cepMessage = 'Consultando CEP...';
    });
    try {
      final address = await _cepService.buscaCEP(cep);
      // Descarta a resposta se o usuário alterou o CEP durante a consulta.
      if (!mounted || request != _cepRequest) return;
      setState(() {
        _logradouroController.text = address['logradouro'] as String? ?? '';
        _bairroController.text = address['bairro'] as String? ?? '';
        _cidadeController.text = address['localidade'] as String? ?? '';
        _ufController.text = address['uf'] as String? ?? '';
        _complementoController.text = address['complemento'] as String? ?? '';
        _userEdited = true;
        _cepMessage =
            'Endereço preenchido. Informe o número e confira o complemento.';
      });
    } on FormatException catch (error) {
      if (!mounted || request != _cepRequest) return;
      setState(() {
        _cepError = error.message;
        _cepMessage = null;
      });
    } catch (error) {
      if (!mounted || request != _cepRequest) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(
        () => _cepMessage =
            '$message Você pode preencher o endereço manualmente.',
      );
      _message(message);
    } finally {
      if (mounted && request == _cepRequest) {
        setState(() => _loadingCep = false);
      }
    }
  }

  Future<void> _saveContact() async {
    if (_saving || _loadingCep || _selectingImage) return;
    _updateContact();
    if (_editContact.name.isEmpty) {
      _message('Nome é obrigatório!');
      return;
    }
    if (!isValidEmail(_editContact.email)) {
      setState(
        () => _emailError = 'Informe um e-mail válido. Ex.: nome@dominio.com',
      );
      _message('E-mail inválido. Confira o endereço antes de salvar.');
      return;
    }
    if ((_editContact.cep.isNotEmpty &&
            _editContact.cep.replaceAll(RegExp(r'\D'), '').length != 8) ||
        _cepError != null) {
      setState(() => _cepError ??= 'Informe um CEP válido com 8 dígitos.');
      _message(_cepError!);
      return;
    }
    setState(() => _saving = true);
    try {
      final image = _editContact.img;
      if (image != null && image.isNotEmpty && image != widget.contact?.img) {
        _editContact.img = await _photoService.savePhoto(image);
      }
      if (_editContact.id != null) {
        await _helper.updateContact(_editContact);
      } else {
        await _helper.saveContact(_editContact);
      }
      if (!mounted) return;
      setState(() {
        _userEdited = false;
        _saving = false;
      });
      Navigator.pop(context, _editContact);
    } catch (_) {
      _message('Não foi possível salvar o contato. Tente novamente.');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmBack() async {
    if (_saving || _selectingImage) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'As alterações deste contato ainda não foram salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _userEdited = false);
      // Atualiza o PopScope antes de concluir a navegação.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Widget _addressField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: TextField(
      controller: controller,
      readOnly: _loadingCep && controller != _numeroController,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (_) => setState(() => _userEdited = true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final image = _editContact.img;
    final hasImage =
        image != null && image.isNotEmpty && File(image).existsSync();
    return PopScope(
      canPop: !_userEdited && !_saving && !_selectingImage,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmBack();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: Text(
            _editContact.name.isEmpty ? 'Novo Contato' : _editContact.name,
          ),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Salvar contato',
          backgroundColor: Colors.blue,
          onPressed: _saving || _loadingCep || _selectingImage
              ? null
              : _saveContact,
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
        ),
        body: AbsorbPointer(
          absorbing: _saving || _selectingImage,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: _selectImage,
                  child: Semantics(
                    button: true,
                    label:
                        'Foto do contato. Toque para tirar foto ou selecionar da galeria.',
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: hasImage
                              ? FileImage(File(image))
                              : const AssetImage('assets/imgs/image.png')
                                    as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Toque na foto para usar a câmera ou galeria'),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (text) => setState(() {
                    _userEdited = true;
                    _editContact.name = text;
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'nome@dominio.com',
                    errorText: _emailError,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [EmailInputFormatter()],
                  onChanged: (text) => setState(() {
                    _userEdited = true;
                    _editContact.email = text;
                    _emailError = null;
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [phoneMask],
                  onChanged: (text) => setState(() {
                    _userEdited = true;
                    _editContact.phone = text;
                  }),
                ),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Endereço do contato',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _cepController,
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    hintText: '00000-000',
                    errorText: _cepError,
                    suffixIcon: _loadingCep
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Consultar CEP',
                            icon: const Icon(Icons.search),
                            onPressed: _searchCep,
                          ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [cepMask],
                  onChanged: _cepChanged,
                  onSubmitted: (_) => _searchCep(),
                ),
                if (_cepMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_cepMessage!),
                    ),
                  ),
                _addressField('Logradouro', _logradouroController),
                _addressField('Bairro', _bairroController),
                _addressField('Cidade', _cidadeController),
                _addressField(
                  'Estado/UF',
                  _ufController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(2),
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  ],
                ),
                _addressField(
                  'Número',
                  _numeroController,
                  keyboardType: TextInputType.streetAddress,
                ),
                _addressField('Complemento', _complementoController),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
