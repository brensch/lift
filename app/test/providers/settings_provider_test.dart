/// Settings are account events: the provider reads them back from the core
/// and fills in what the account never recorded (plate colours, mostly).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/logic/weight_units.dart';
import 'package:schlift/providers/settings_provider.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;

  setUp(() async {
    h = await ProviderHarness.boot();
  });

  tearDown(() => h.dispose());

  const kg = WeightUnit.WEIGHT_UNIT_KG;
  const lb = WeightUnit.WEIGHT_UNIT_LB;

  void expectDefaults(SettingsProvider s, WeightUnit unit) {
    expect(s.weightUnit, unit);
    final defaults = SettingsProvider.defaultPlateColors(unit);
    for (final plate in standardPlates(unit)) {
      expect(s.plateColor(plate), defaults[plate], reason: '$plate');
    }
  }

  test('a kg account with no plate colours gets the kg defaults', () async {
    await h.service.updateSetting(
      UserSetting(weightUnit: WeightUnitConfig(unit: kg)),
    );
    await h.settings.load();
    expectDefaults(h.settings, kg);
    expect(h.settings.plateColor(20), Colors.blue);
  });

  test('switching to kg shows every kg plate in its default colour', () async {
    await h.settings.load();
    expectDefaults(h.settings, lb);
    await h.settings.updateWeightUnit(kg);
    expectDefaults(h.settings, kg);

    // And it was recorded: a fresh provider reads kg back.
    final fresh = SettingsProvider(h.service);
    await fresh.load();
    expectDefaults(fresh, kg);
  });

  test('onboarding in kg, right after a load, shows kg plates', () async {
    await h.settings.load();
    h.settings.applyWeightUnitLocally(kg);
    expectDefaults(h.settings, kg);
  });

  test('chosen colours are kept across a load and a unit change', () async {
    await h.settings.load();
    const pink = Color(0xFFFF00FF);
    await h.settings.updatePlateColors({
      ...h.settings.plateColors,
      25: pink,
    });

    final fresh = SettingsProvider(h.service);
    await fresh.load();
    expect(fresh.plateColor(25), pink);
    expect(fresh.plateColor(45).toARGB32(), Colors.red.toARGB32());

    // 25 is a kg plate too; the kg-only plates get kg defaults.
    fresh.applyWeightUnitLocally(kg);
    expect(fresh.plateColor(25), pink);
    expect(fresh.plateColor(20).toARGB32(), Colors.blue.toARGB32());
    expect(fresh.plateColor(1.25), isNot(Colors.purple));
  });

  test('a load notifies once, with the recorded values', () async {
    await h.service.updateSetting(
      UserSetting(weightUnit: WeightUnitConfig(unit: kg)),
    );
    await h.settings.load();
    final seen = <WeightUnit>[];
    h.settings.addListener(() => seen.add(h.settings.weightUnit));
    await h.settings.load();
    expect(seen, [kg], reason: 'no flash of lb before the read');
  });

  test('clear goes back to lb defaults', () async {
    await h.settings.updateWeightUnit(kg);
    h.settings.clear();
    expectDefaults(h.settings, lb);
  });
}
