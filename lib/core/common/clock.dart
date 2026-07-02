/// Horloge injectable — jamais de `DateTime.now()` en dur dans le domaine.
abstract class Clock {
  int nowMs();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}
