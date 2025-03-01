class HostModel {
  final String currentHost;

  HostModel({required this.currentHost});

  Map<String, dynamic> toJson() {
    return {'current_host': currentHost};
  }

  factory HostModel.fromJson(Map<String, dynamic> json) {
    return HostModel(currentHost: json['current_host']);
  }
}