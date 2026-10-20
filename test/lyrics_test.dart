import 'package:flutter_test/flutter_test.dart';
import 'package:sonaplay/features/player/domain/lyrics.dart';

void main() {
  const raw = '''[ar:Aqua]
[00:15.069] I'm a Barbie girl
[00:18.869][01:00.000] Life in plastic
[00:22.1] <00:22.10>You <00:22.50>can
''';

  test('parses stamps, repeated lines and word stamps', () {
    final lines = parseLyrics(raw);
    expect(lines.map((l) => l.text), [
      "I'm a Barbie girl",
      'Life in plastic',
      'You can',
      'Life in plastic',
    ]);
    expect(lines.first.time, const Duration(seconds: 15, milliseconds: 69));
    expect(lines[2].time, const Duration(seconds: 22, milliseconds: 100));
  });

  test('plain text stays plain', () {
    final lines = parseLyrics('Hola\n\nmundo');
    expect(lines.map((l) => l.text), ['Hola', 'mundo']);
    expect(lines.first.time, isNull);
  });

  test('current line and progress', () {
    final lines = parseLyrics(raw);
    expect(lineAt(lines, const Duration(seconds: 3)), -1);
    expect(lineAt(lines, const Duration(seconds: 16)), 0);
    expect(lineAt(lines, const Duration(minutes: 2)), 3);
    expect(lineProgress(lines, 0, const Duration(seconds: 15)), 0);
    expect(lineProgress(lines, 0, const Duration(seconds: 18)), 1);
  });

  test('words light up by length', () {
    expect(litWords('a bb ccc', 0).lit, 1);
    expect(litWords('a bb ccc', 0.4).lit, 2);
    expect(litWords('a bb ccc', 1).lit, 3);
  });
}
