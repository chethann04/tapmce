import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_haptics.dart';

/// Floating search bar widget with dynamic filter chips for student queues & drive listings.
class AppSearchFilterBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final List<String> filterOptions;
  final String? selectedFilter;
  final ValueChanged<String>? onFilterSelected;

  const AppSearchFilterBar({
    super.key,
    this.hintText = 'Search by name, USN, or department...',
    required this.onSearchChanged,
    this.filterOptions = const [],
    this.selectedFilter,
    this.onFilterSelected,
  });

  @override
  State<AppSearchFilterBar> createState() => _AppSearchFilterBarState();
}

class _AppSearchFilterBarState extends State<AppSearchFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floating Search Input Container
        Container(
          height: 48,
          decoration: ShapeDecoration(
            color: theme.colorScheme.surface,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
              side: BorderSide(color: brandTheme.cardBorder),
            ),
            shadows: brandTheme.shadow2,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: brandTheme.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: brandTheme.textMuted),
                      onPressed: () {
                        AppHaptics.selectionClick();
                        _searchController.clear();
                        widget.onSearchChanged('');
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // Filter Chips Row (If Provided)
        if (widget.filterOptions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sp3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.filterOptions.map((filter) {
                final isSelected = widget.selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sp2),
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selectionClick();
                      widget.onFilterSelected?.call(filter);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandTheme.brassPrimary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppShapes.radiusPill),
                        border: Border.all(
                          color: isSelected
                              ? brandTheme.brassPrimary
                              : brandTheme.cardBorder,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? brandTheme.onBrass : brandTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
