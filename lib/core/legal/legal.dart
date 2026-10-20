import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Raise it when the terms or the privacy notice change in a way users must
/// accept again; the app asks on the next launch
const kTermsVersion = 1;

// ponytail: fill in before publishing; the privacy notice must show both
const kSupportEmail = '[correo de soporte por definir]';
const kResponsibleAddress = '[domicilio por definir]';

const kTermsAsset = 'assets/legal/terminos.md';
const kPrivacyAsset = 'assets/legal/privacidad.md';

/// Whether the current terms were accepted on this device
final termsAcceptedProvider = NotifierProvider<TermsNotifier, bool>(
  TermsNotifier.new,
);

class TermsNotifier extends Notifier<bool> {
  Box get _box => Hive.box('settings_box');

  @override
  bool build() => (_box.get('terms_version') as int? ?? 0) >= kTermsVersion;

  /// Keeps the version and the date, as a record of the acceptance
  void accept() {
    _box.put('terms_version', kTermsVersion);
    _box.put('terms_accepted_at', DateTime.now().toIso8601String());
    state = true;
  }
}

void openLegal(BuildContext context, {required bool privacy}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => LegalScreen(
      title: privacy ? 'Aviso de Privacidad' : 'Términos y Condiciones',
      asset: privacy ? kPrivacyAsset : kTermsAsset,
    ),
  ),
);

/// A legal document from the assets. Understands the little Markdown they
/// use: "# " title, "## " headings, "- " bullets and **bold**.
class LegalScreen extends StatelessWidget {
  final String title;
  final String asset;
  const LegalScreen({super.key, required this.title, required this.asset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.5);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: rootBundle.loadString(asset),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lines = snap.data!
              .replaceAll('{{email}}', kSupportEmail)
              .replaceAll('{{address}}', kResponsibleAddress)
              .split('\n');
          // Nearly solid: long text over a busy background is hard to read
          return ColoredBox(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            child: SelectionArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  40 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  for (final line in lines)
                    if (line.startsWith('# '))
                      const SizedBox.shrink() // already in the app bar
                    else if (line.startsWith('## '))
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 6),
                        child: Text(
                          line.substring(3),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else if (line.startsWith('- '))
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•  ', style: body),
                            Expanded(child: _rich(line.substring(2), body)),
                          ],
                        ),
                      )
                    else if (line.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _rich(line, body),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// **bold** runs inside a line
  static Widget _rich(String text, TextStyle? style) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, part) in parts.indexed)
            TextSpan(
              text: part,
              style: i.isOdd
                  ? const TextStyle(fontWeight: FontWeight.w800)
                  : null,
            ),
        ],
      ),
    );
  }
}
