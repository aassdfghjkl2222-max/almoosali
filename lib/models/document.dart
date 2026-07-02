class Document {
  final String id;
  final String title;
  final String number;
  final DateTime expiryDate;
  final bool expired;

  const Document({
    required this.id,
    required this.title,
    required this.number,
    required this.expiryDate,
    required this.expired,
  });
}