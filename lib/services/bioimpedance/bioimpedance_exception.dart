/// Erro de leitura local, mostrado ao usuário na tela de importação.
class LocalParseException implements Exception {
  const LocalParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
