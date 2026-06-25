/// Choisit le mot selon le nombre (français : 0 et 1 → singulier).
String pluralize(int n, String singular, String plural) =>
    n <= 1 ? singular : plural;

/// Compte de passages lisible :
/// `0 → "Aucun passage"`, `1 → "1 passage"`, `n → "n passages"`.
String passageCount(int n) =>
    n == 0 ? 'Aucun passage' : '$n ${pluralize(n, 'passage', 'passages')}';
