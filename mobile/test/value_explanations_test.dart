import 'package:flutter_test/flutter_test.dart';
import 'package:work_hours_mobile/presentation/home/logic/value_explanations.dart';

void main() {
  test('ogni valore ha una spiegazione completa', () {
    for (final value in ExplainableValue.values) {
      final explanation = explanationFor(value);

      expect(explanation.title.trim(), isNotEmpty, reason: '$value');
      expect(explanation.meaning.trim(), isNotEmpty, reason: '$value');
      expect(explanation.source.trim(), isNotEmpty, reason: '$value');
    }
  });

  test('chi manda alle impostazioni dice anche quale riquadro cercare', () {
    for (final value in ExplainableValue.values) {
      final explanation = explanationFor(value);
      if (explanation.settingsSection == null) {
        continue;
      }

      expect(explanation.settingsHint?.trim(), isNotEmpty, reason: '$value');
    }
  });

  test('le spiegazioni non usano parole da addetti ai lavori', () {
    // Nomi che esistono solo nel codice: a schermo non devono comparire.
    const jargon = ['override', 'snapshot', 'target', 'session', 'null'];
    for (final value in ExplainableValue.values) {
      final explanation = explanationFor(value);
      final text =
          '${explanation.meaning} ${explanation.source}'.toLowerCase();
      for (final word in jargon) {
        expect(text.contains(word), isFalse, reason: '$value usa "$word"');
      }
    }
  });
}
