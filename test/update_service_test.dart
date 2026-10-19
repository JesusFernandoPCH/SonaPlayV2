import 'package:flutter_test/flutter_test.dart';
import 'package:sonaplay/core/services/update_service.dart';

void main() {
  test('isVersionLower compares each part as a number', () {
    expect(isVersionLower('1.0.0', '1.0.1'), isTrue);
    expect(isVersionLower('1.9.0', '1.10.0'), isTrue);
    expect(isVersionLower('2.0.0', '1.10.0'), isFalse);
    expect(isVersionLower('1.0.0', '1.0.0'), isFalse);
    expect(isVersionLower('1.0', '1.0.1'), isTrue);
  });
}
