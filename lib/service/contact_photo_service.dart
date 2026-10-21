import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/model/contact_model.dart';

class ContactPhotoService {
  Future<String> savePhoto(String sourcePath) async {
    try {
      if (await FileSystemEntity.type(sourcePath, followLinks: false) !=
          FileSystemEntityType.file) {
        throw Exception('A foto não está disponível. Selecione outra imagem.');
      }

      final documents = await getApplicationDocumentsDirectory();
      final photos = Directory(path.join(documents.path, 'photos'));
      await photos.create(recursive: true);
      final source = File(sourcePath).absolute;

      // Fotos já guardadas pelo aplicativo não precisam de outra cópia.
      if (path.equals(source.parent.path, photos.absolute.path)) {
        return source.path;
      }

      var extension = path.extension(source.path);
      if (!RegExp(r'^\.[a-zA-Z0-9]{1,10}$').hasMatch(extension)) {
        extension = '.jpg';
      }
      final destination = path.join(
        photos.path,
        'contato_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      return (await source.copy(destination)).path;
    } on FileSystemException {
      throw Exception('Não foi possível guardar a foto. Tente novamente.');
    }
  }

  Future<File> _draftFile() async {
    final documents = await getApplicationDocumentsDirectory();
    return File(path.join(documents.path, 'contact_photo_draft.json'));
  }

  Future<void> saveDraft(Contact contact) async {
    try {
      final file = await _draftFile();
      await file.writeAsString(json.encode(contact.toMap()), flush: true);
    } on FileSystemException {
      throw Exception(
        'Não foi possível guardar o rascunho do contato. Tente novamente.',
      );
    }
  }

  Future<Contact?> recoverDraft() async {
    final file = await _draftFile();
    if (!await file.exists()) {
      return null;
    }
    try {
      final dados = json.decode(await file.readAsString());
      if (dados is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return Contact.fromMap(dados);
    } on FormatException {
      throw Exception('Não foi possível recuperar o rascunho do contato.');
    } on FileSystemException {
      throw Exception('Não foi possível recuperar o rascunho do contato.');
    }
  }

  Future<void> clearDraft() async {
    final file = await _draftFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Contact?> recoverLostPhoto() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty) {
        return null;
      }
      if (response.exception != null) {
        throw Exception(
          'Não foi possível recuperar a foto. Selecione a imagem novamente.',
        );
      }
      final files = response.files;
      if (files == null || files.isEmpty) {
        return null;
      }

      final contact = await recoverDraft();
      if (contact == null) {
        throw Exception(
          'O rascunho do contato não está disponível. '
          'Selecione a foto novamente.',
        );
      }
      contact.img = await savePhoto(files.first.path);
      return contact;
    } on PlatformException {
      throw Exception(
        'Não foi possível recuperar a foto. Selecione a imagem novamente.',
      );
    } finally {
      await clearDraft();
    }
  }
}
