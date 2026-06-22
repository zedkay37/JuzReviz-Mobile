/// Horloge injectable — jamais de `DateTime.now()` en dur dans le domaine.
abstract class Clock {
  int nowMs();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

class FixedClock implements Clock {
  FixedClock(this._ms);
  int _ms;
  set ms(int value) => _ms = value;
  @override
  int nowMs() => _ms;
}
