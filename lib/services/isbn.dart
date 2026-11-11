/// Utilidades de ISBN (validação e conversão 10 → 13).
String cleanIsbn(String s) => s.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();

bool isValidIsbn13(String s) {
  if (!RegExp(r'^\d{13}$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(s[i]) * (i.isOdd ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == int.parse(s[12]);
}

bool isValidIsbn10(String s) {
  if (!RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    sum += (s[i] == 'X' ? 10 : int.parse(s[i])) * (10 - i);
  }
  return sum % 11 == 0;
}

String isbn10to13(String s) {
  final core = '978${s.substring(0, 9)}';
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(core[i]) * (i.isOdd ? 3 : 1);
  }
  return '$core${(10 - sum % 10) % 10}';
}

/// Se o texto for um ISBN válido, devolve-o com 13 dígitos.
String? asIsbn(String text) {
  final c = cleanIsbn(text);
  if (isValidIsbn13(c)) return c;
  if (isValidIsbn10(c)) return isbn10to13(c);
  return null;
}

/// Código de barras de livro: EAN-13 começando com 978 ou 979.
bool isBookEan(String s) => RegExp(r'^97[89]\d{10}$').hasMatch(s) && isValidIsbn13(s);
