int calculateAge(String? uid) {
  if (uid == null || uid.trim().isEmpty) {
    return 22;
  }
  return (uid.hashCode.abs() % 6) + 20;
}
