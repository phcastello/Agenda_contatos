import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/helper/contact_helper.dart';
import '../database/model/contact_model.dart';
import 'contact_page.dart';

enum OrderOptions { orderAZ, orderZA }

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.recoveredContact, this.recoveryMessage});

  final Contact? recoveredContact;
  final String? recoveryMessage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ContactHelper helper = ContactHelper();
  List<Contact> contacts = [];
  bool _loading = true;
  OrderOptions? _order;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getAllContacts();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.recoveryMessage != null) {
        _showError(widget.recoveryMessage!);
      }
      if (widget.recoveredContact != null) {
        _showContactPage(
          contact: widget.recoveredContact,
          recoveredDraft: true,
        );
      }
    });
  }

  Future<void> _getAllContacts() async {
    try {
      final list = await helper.getAllContacts();
      if (!mounted) return;
      setState(() {
        contacts = list;
        _loading = false;
        if (_order != null) _sortContacts(_order!);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Não foi possível carregar os contatos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Contatos'),
        backgroundColor: Colors.blue,
        centerTitle: true,
        actions: <Widget>[
          PopupMenuButton<OrderOptions>(
            itemBuilder: (context) => <PopupMenuEntry<OrderOptions>>[
              const PopupMenuItem<OrderOptions>(
                value: OrderOptions.orderAZ,
                child: Text('Ordenar de A-Z'),
              ),
              const PopupMenuItem<OrderOptions>(
                value: OrderOptions.orderZA,
                child: Text('Ordenar de Z-A'),
              ),
            ],
            onSelected: _orderList,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactPage(),
        backgroundColor: Colors.blue,
        tooltip: 'Novo contato',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
          ? const Center(child: Text('Nenhum contato cadastrado.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 90.0),
              itemCount: contacts.length,
              itemBuilder: (context, index) => _contactCard(context, index),
            ),
    );
  }

  Widget _contactCard(BuildContext context, int index) {
    final contact = contacts[index];
    final imagePath = contact.img;
    final ImageProvider avatar =
        imagePath != null && File(imagePath).existsSync()
        ? FileImage(File(imagePath))
        : const AssetImage('assets/imgs/image.png');
    final address = _address(contact);

    return GestureDetector(
      onTap: () => _showOptions(context, index),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: <Widget>[
              Container(
                width: 80.0,
                height: 80.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: avatar, fit: BoxFit.cover),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contact.email,
                        style: const TextStyle(fontSize: 18.0),
                      ),
                      Text(
                        contact.phone,
                        style: const TextStyle(fontSize: 18.0),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 6.0),
                        Text(
                          address,
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _address(Contact contact) {
    final street = [
      contact.logradouro,
      contact.numero,
    ].where((value) => value.trim().isNotEmpty).join(', ');
    final city = [
      contact.cidade,
      contact.uf,
    ].where((value) => value.trim().isNotEmpty).join('/');
    return [
      street,
      contact.complemento,
      contact.bairro,
      city,
      if (contact.cep.isNotEmpty) 'CEP: ${contact.cep}',
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }

  Future<void> _showContactPage({
    Contact? contact,
    bool recoveredDraft = false,
  }) async {
    final updatedContact = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ContactPage(contact: contact, recoveredDraft: recoveredDraft),
      ),
    );
    if (updatedContact != null && mounted) {
      await _getAllContacts();
    }
  }

  void _showOptions(BuildContext context, int index) {
    final contact = contacts[index];
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _callContact(contact);
                  },
                  child: const Text(
                    'Ligar',
                    style: TextStyle(color: Colors.green, fontSize: 20.0),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showContactPage(contact: contact);
                  },
                  child: const Text(
                    'Editar',
                    style: TextStyle(color: Colors.blue, fontSize: 20.0),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _deleteContact(contact);
                  },
                  child: const Text(
                    'Excluir',
                    style: TextStyle(color: Colors.red, fontSize: 20.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _callContact(Contact contact) async {
    final phone = contact.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      _showError('O contato não possui um telefone informado.');
      return;
    }
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!opened && mounted) {
        _showError('Não foi possível abrir o discador.');
      }
    } catch (_) {
      if (mounted) _showError('Não foi possível abrir o discador.');
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    if (contact.id == null) {
      _showError('Erro: ID do contato não encontrado.');
      return;
    }
    try {
      await helper.deleteContact(contact.id!);
      if (!mounted) return;
      setState(() {
        contacts.removeWhere((item) => item.id == contact.id);
      });
    } catch (_) {
      if (mounted) _showError('Não foi possível excluir o contato.');
    }
  }

  void _sortContacts(OrderOptions result) {
    switch (result) {
      case OrderOptions.orderAZ:
        contacts.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case OrderOptions.orderZA:
        contacts.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    }
  }

  void _orderList(OrderOptions result) {
    setState(() {
      _order = result;
      _sortContacts(result);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
