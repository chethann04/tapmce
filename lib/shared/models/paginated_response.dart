class PaginatedResponse<T> {
  final List<T> items;
  final int totalCount;
  
  const PaginatedResponse({
    required this.items,
    required this.totalCount,
  });
}
