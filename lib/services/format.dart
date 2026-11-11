const months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayIso() => isoDate(DateTime.now());

DateTime? parseIso(String? s) => s == null ? null : DateTime.tryParse(s);

String fmtDate(String? iso) {
  final d = parseIso(iso);
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

/// 1234 -> "1.234"
String fmtInt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtRating(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

String plural(int n, String one, String many) => '${fmtInt(n)} ${n == 1 ? one : many}';
