/// Every text the user sees. The app is Polish-only, so these are plain
/// constants rather than Flutter's l10n tooling.
abstract final class Strings {
  // Zones screen
  static const permanent = 'Na stałe';
  static String hours(int hours) => '$hours h';
  static String now(String temperature) => 'Teraz $temperature';
  static const noReading = 'Brak odczytu';
  static const heating = 'Grzeje';
  static String decrease(String zone) => 'Obniż temperaturę: $zone';
  static String increase(String zone) => 'Podnieś temperaturę: $zone';
  static const noZones = 'Brak stref w tym sterowniku';
  static String changeFailed(String zone, String reason) =>
      '$zone: nie udało się ustawić temperatury. $reason';

  // Modules screen
  static const pickController = 'Wybierz sterownik';
  static const noControllers = 'Brak sterowników na koncie eModul';

  // Shared
  static const retry = 'Spróbuj ponownie';

  // eModul errors
  static const serverTimeout = 'Serwer eModul nie odpowiada';
  static String connectionFailed(String detail) =>
      'Brak połączenia z eModul ($detail)';
  static const tokenRevoked =
      'Token API jest nieważny. Wygeneruj nowy na emodul.pl i zbuduj apkę ponownie.';
  static String serverError(int status) => 'eModul zwrócił błąd $status';
  static const unreadableResponse = 'Niezrozumiała odpowiedź z eModul';
  static const unexpectedData = 'Nieoczekiwany format danych z eModul';

  // Build configuration
  static const tokenMissing = 'Brak tokena API';
  static const tokenNotJwt = 'Token API nie jest JWT';
  static const tokenWithoutUserId = 'Token API bez user_id';
  static String buildConfigError(String reason) =>
      '$reason.\n\nWklej token z emodul.pl do secrets.json '
      'i zbuduj apkę przez rps dev albo rps install.';
}
