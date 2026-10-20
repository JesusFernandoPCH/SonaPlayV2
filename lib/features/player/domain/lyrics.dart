/// One line of lyrics; [time] is null for plain (unsynced) lyrics
class LyricLine {
  final Duration? time;
  final String text;
  const LyricLine(this.text, [this.time]);
}

final _stamp = RegExp(r'\[(\d+):(\d+(?:[.:]\d+)?)\]');
final _tag = RegExp(r'^\[[a-z]+:.*\]$', caseSensitive: false);
final _wordStamp = RegExp(r'<\d+:\d+(?:[.:]\d+)?>');

/// Parses LRC ("[01:02.34] text"); text without stamps becomes plain lines.
/// Lines with several stamps (repeated choruses) are listed at each time.
/// ponytail: word stamps (<mm:ss.xx>) are dropped, words are timed by length
List<LyricLine> parseLyrics(String raw) {
  final synced = <LyricLine>[];
  final plain = <LyricLine>[];
  for (final row in raw.split(RegExp(r'\r?\n'))) {
    final line = row.trim();
    if (line.isEmpty || _tag.hasMatch(line)) continue;
    final stamps = _stamp.allMatches(line).toList();
    final text = line.replaceAll(_stamp, '').replaceAll(_wordStamp, '').trim();
    if (stamps.isEmpty) {
      plain.add(LyricLine(text));
      continue;
    }
    for (final m in stamps) {
      final seconds = double.parse(m.group(2)!.replaceAll(':', '.'));
      final time = Duration(
        minutes: int.parse(m.group(1)!),
        milliseconds: (seconds * 1000).round(),
      );
      synced.add(LyricLine(text, time));
    }
  }
  if (synced.isEmpty) return plain;
  return synced..sort((a, b) => a.time!.compareTo(b.time!));
}

/// Index of the line being sung at [position]; -1 before the first one
int lineAt(List<LyricLine> lines, Duration position) {
  var index = -1;
  for (final (i, line) in lines.indexed) {
    if (line.time == null || line.time! > position) break;
    index = i;
  }
  return index;
}

/// How much of line [i] has been sung (0 to 1). The line lasts until the
/// next one, but no longer than its length suggests, so a long instrumental
/// gap doesn't stretch the words.
double lineProgress(List<LyricLine> lines, int i, Duration position) {
  if (i < 0) return 0;
  final start = lines[i].time!;
  final byLength = Duration(milliseconds: 600 + lines[i].text.length * 90);
  final next = i + 1 < lines.length ? lines[i + 1].time! : start + byLength;
  final span = next - start < byLength ? next - start : byLength;
  if (span <= Duration.zero) return 1;
  return ((position - start).inMilliseconds / span.inMilliseconds).clamp(0, 1);
}

/// Words of [text] and how many of them are lit at [progress] (the current
/// one included), timed by their length
({List<String> words, int lit}) litWords(String text, double progress) {
  final words = text.split(' ');
  final total = text.replaceAll(' ', '').length;
  if (total == 0) return (words: words, lit: words.length);
  var chars = 0;
  var lit = 0;
  for (final w in words) {
    if (chars / total > progress) break;
    chars += w.length;
    lit++;
  }
  return (words: words, lit: progress >= 1 ? words.length : lit);
}
