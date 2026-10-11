class AdapterModel {
  final bool powered;
  final bool discovering;
  final String address;
  final String name;
  final String alias;

  const AdapterModel({
    required this.powered,
    required this.discovering,
    required this.address,
    required this.name,
    required this.alias,
  });

  factory AdapterModel.fromJson(Map<String, dynamic> json) {
    return AdapterModel(
      powered: json['powered'] ?? false,
      discovering: json['discovering'] ?? false,
      address: json['address'] ?? '',
      name: json['name'] ?? '',
      alias: json['alias'] ?? '',
    );
  }
}
