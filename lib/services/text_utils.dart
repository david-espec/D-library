/// Minúsculas, sem acentos e sem pontuação: para comparar títulos.
String norm(String? s) {
  if (s == null) return '';
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? yearOf(Object? date) {
  if (date == null) return null;
  return RegExp(r'\d{4}').firstMatch(date.toString())?.group(0);
}

/// Remove HTML (as sinopses do Google Books vêm com <p>, <b>, <br>…).
String? stripHtml(String? html) {
  if (html == null) return null;
  var s = html.replaceAll(RegExp(r'<\s*(br|/p|/div|/li)\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {'&amp;': '&', '&quot;': '"', '&#39;': "'", '&lt;': '<', '&gt;': '>', '&nbsp;': ' '};
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return s.isEmpty ? null : s;
}

const _categoryPt = {
  'fiction': 'Ficção',
  'science fiction': 'Ficção científica',
  'fantasy': 'Fantasia',
  'history': 'História',
  'philosophy': 'Filosofia',
  'biography': 'Biografia',
  'biography & autobiography': 'Biografia',
  'juvenile fiction': 'Infantojuvenil',
  'juvenile nonfiction': 'Infantojuvenil',
  'young adult fiction': 'Jovem adulto',
  'self-help': 'Autoajuda',
  'psychology': 'Psicologia',
  'science': 'Ciência',
  'business & economics': 'Negócios',
  'business': 'Negócios',
  'economics': 'Economia',
  'religion': 'Religião',
  'poetry': 'Poesia',
  'literary criticism': 'Crítica literária',
  'literary collections': 'Coletâneas',
  'social science': 'Ciências sociais',
  'political science': 'Política',
  'computers': 'Tecnologia',
  'technology & engineering': 'Tecnologia',
  'education': 'Educação',
  'art': 'Arte',
  'comics & graphic novels': 'Quadrinhos',
  'cooking': 'Culinária',
  'health & fitness': 'Saúde',
  'body, mind & spirit': 'Espiritualidade',
  'family & relationships': 'Relacionamentos',
  'romance': 'Romance',
  'mystery': 'Mistério',
  'thriller': 'Suspense',
  'horror': 'Terror',
  'travel': 'Viagem',
  'drama': 'Drama',
  'mathematics': 'Matemática',
  'medical': 'Medicina',
  'law': 'Direito',
  'true crime': 'Crime real',
  'humor': 'Humor',
  'music': 'Música',
  'nature': 'Natureza',
  'sports & recreation': 'Esportes',
  'classics': 'Clássicos',
};

String translateCategory(String raw) {
  final head = raw.split('/').first.trim();
  final t = _categoryPt[head.toLowerCase()];
  if (t != null) return t;
  return head.isEmpty ? head : head[0].toUpperCase() + head.substring(1);
}

List<String> cleanCategories(List<String>? raw, {int max = 3}) {
  final out = <String>[];
  for (final c in (raw ?? const <String>[]).map(translateCategory)) {
    if (c.length > 1 && c.length < 40 && !out.contains(c)) out.add(c);
    if (out.length == max) break;
  }
  return out;
}

/// Distância de edição com limite, para tolerar erros do OCR ("Saplens" ~ "Sapiens").
bool closeEnough(String a, String b) {
  if (a == b) return true;
  final max = a.length >= 7 ? 2 : a.length >= 4 ? 1 : 0;
  if (max == 0 || (a.length - b.length).abs() > max) return false;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length] <= max;
}
