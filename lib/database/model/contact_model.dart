String idColumn = 'idColumn';
String nameColumn = 'nameColumn';
String emailColumn = 'emailColumn';
String phoneColumn = 'phoneColumn';
String imgColumn = 'imgColumn';
String contactTable = 'contactTable';
String cepColumn = 'cepColumn';
String logradouroColumn = 'logradouroColumn';
String bairroColumn = 'bairroColumn';
String cidadeColumn = 'cidadeColumn';
String ufColumn = 'ufColumn';
String numeroColumn = 'numeroColumn';
String complementoColumn = 'complementoColumn';

class Contact {
  Contact({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.img,
    this.cep = '',
    this.logradouro = '',
    this.bairro = '',
    this.cidade = '',
    this.uf = '',
    this.numero = '',
    this.complemento = '',
  });

  int? id;
  String name;
  String email;
  String phone;
  String? img;
  String cep;
  String logradouro;
  String bairro;
  String cidade;
  String uf;
  String numero;
  String complemento;

  Contact.fromMap(Map<String, dynamic> map)
    : id = map[idColumn],
      name = map[nameColumn] ?? '',
      email = map[emailColumn] ?? '',
      phone = map[phoneColumn] ?? '',
      img = map[imgColumn],
      cep = map[cepColumn] ?? '',
      logradouro = map[logradouroColumn] ?? '',
      bairro = map[bairroColumn] ?? '',
      cidade = map[cidadeColumn] ?? '',
      uf = map[ufColumn] ?? '',
      numero = map[numeroColumn] ?? '',
      complemento = map[complementoColumn] ?? '';

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      nameColumn: name,
      emailColumn: email,
      phoneColumn: phone,
      imgColumn: img,
      cepColumn: cep,
      logradouroColumn: logradouro,
      bairroColumn: bairro,
      cidadeColumn: cidade,
      ufColumn: uf,
      numeroColumn: numero,
      complementoColumn: complemento,
    };
    if (id != null) {
      map[idColumn] = id;
    }
    return map;
  }

  @override
  String toString() {
    return 'Contact(id: $id, name: $name, '
        'email: $email, phone: $phone, img: $img, '
        'cep: $cep, logradouro: $logradouro, bairro: $bairro, '
        'cidade: $cidade, uf: $uf, numero: $numero, '
        'complemento: $complemento)';
  }
}
