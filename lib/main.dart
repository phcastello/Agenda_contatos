import 'package:flutter/material.dart';
import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:apk_agenda_bd_local/service/contact_photo_service.dart';
import 'package:apk_agenda_bd_local/view/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Contact? recoveredContact;
  String? recoveryMessage;
  try {
    recoveredContact = await ContactPhotoService().recoverLostPhoto();
  } catch (error) {
    recoveryMessage = error.toString().replaceFirst('Exception: ', '');
  }
  runApp(
    MaterialApp(
      title: 'Agenda de Contatos',
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: HomePage(
        recoveredContact: recoveredContact,
        recoveryMessage: recoveryMessage,
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}
