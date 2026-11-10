class JobOpportunity {
  const JobOpportunity({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.location,
    required this.deadline,
    this.hasApplied = false,
  });

  final String id;
  final String title;
  final String company;
  final String description;
  final String location;
  final DateTime deadline;
  final bool hasApplied;

  factory JobOpportunity.fromJson(Map<String, dynamic> json) => JobOpportunity(
        id: json['id'].toString(),
        title: json['title'] as String,
        company: json['company'] as String,
        description: json['description'] as String,
        location: json['location'] as String,
        deadline: DateTime.parse(json['deadline'] as String),
        hasApplied: json['has_applied'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'description': description,
        'location': location,
        'deadline': deadline.toUtc().toIso8601String(),
        'has_applied': hasApplied,
      };
}
