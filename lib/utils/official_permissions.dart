/// 公式アカウント（`users.isOfficial`）向けの権限ヘルパー。

bool canManageTournament({
  required String uid,
  required Map<String, dynamic> tournament,
  bool isAdmin = false,
  bool viewerIsOfficial = false,
}) {
  if (viewerIsOfficial || isAdmin) return true;
  final editors = List<String>.from(tournament['editors'] ?? []);
  return tournament['organizerId'] == uid || editors.contains(uid);
}

bool canEditRecruitment({
  required String uid,
  required String recruitmentUserId,
  bool viewerIsOfficial = false,
}) {
  return recruitmentUserId == uid || viewerIsOfficial;
}
