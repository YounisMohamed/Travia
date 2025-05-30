import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your app colors
import 'AppColors.dart';

/// A reusable custom dropdown widget that uses animated_custom_dropdown package
/// This widget is layout-safe and provides consistent styling across the app
class AppCustomDropdown<T> extends StatelessWidget {
  final List<T> items;
  final T? value;
  final String hintText;
  final Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final Widget? prefixIcon;
  final String? label;
  final bool isRequired;
  final bool enabled;
  final double? width;
  final EdgeInsetsGeometry? contentPadding;
  final bool withSearch;
  final String? searchHintText;
  final TextEditingController? controller;

  const AppCustomDropdown({
    Key? key,
    required this.items,
    required this.hintText,
    this.value,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.label,
    this.isRequired = false,
    this.enabled = true,
    this.width,
    this.contentPadding,
    this.withSearch = false,
    this.searchHintText,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget dropdown;

    // Build the appropriate dropdown based on configuration
    if (withSearch) {
      dropdown = CustomDropdown<T>.search(
        items: items,
        hintText: hintText,
        searchHintText: searchHintText ?? 'Search...',
        onChanged: enabled ? onChanged : null,
        validator: validator,
        initialItem: value,
        enabled: enabled,
        overlayHeight: 300,
        decoration: CustomDropdownDecoration(
          expandedFillColor: Colors.white,
          closedFillColor: enabled ? Colors.white : Colors.grey.shade50,
          hintStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          headerStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          listItemStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.black87,
          ),
          searchFieldDecoration: SearchFieldDecoration(
            fillColor: Colors.grey.shade100,
            hintStyle: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textStyle: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: Colors.black87,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kDeepPink, width: 2),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          closedBorder: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1.5,
          ),
          closedBorderRadius: BorderRadius.circular(12),
          expandedBorder: Border.all(
            color: kDeepPink,
            width: 2,
          ),
          expandedBorderRadius: BorderRadius.circular(12),
          closedSuffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? kDeepPink : Colors.grey.shade400,
            size: 24,
          ),
          expandedSuffixIcon: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: kDeepPink,
            size: 24,
          ),
          prefixIcon: prefixIcon,
        ),
      );
    } else {
      dropdown = CustomDropdown<T>(
        items: items,
        hintText: hintText,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        initialItem: value,
        enabled: enabled,
        overlayHeight: 300,
        decoration: CustomDropdownDecoration(
          expandedFillColor: Colors.white,
          closedFillColor: enabled ? Colors.white : Colors.grey.shade50,
          hintStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          headerStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          listItemStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.black87,
          ),
          closedBorder: Border.all(
            color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1.5,
          ),
          closedBorderRadius: BorderRadius.circular(12),
          expandedBorder: Border.all(
            color: kDeepPink,
            width: 2,
          ),
          expandedBorderRadius: BorderRadius.circular(12),
          closedSuffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? kDeepPink : Colors.grey.shade400,
            size: 24,
          ),
          expandedSuffixIcon: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: kDeepPink,
            size: 24,
          ),
          prefixIcon: prefixIcon,
        ),
      );
    }

    // Wrap with label if provided
    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label!,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kDeepPink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (width != null) SizedBox(width: width, child: dropdown) else dropdown,
        ],
      );
    }

    // Wrap with width if specified
    if (width != null) {
      return SizedBox(width: width, child: dropdown);
    }

    return dropdown;
  }
}

/// Custom dropdown for objects with icons
/// Use this when you need to display items with both text and icons
class AppCustomDropdownWithIcon<T> extends StatelessWidget {
  final List<T> items;
  final T? value;
  final String hintText;
  final Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final Widget? prefixIcon;
  final String? label;
  final bool isRequired;
  final bool enabled;
  final double? width;
  final String Function(T) displayText;
  final Widget? Function(T)? itemIcon;
  final bool withSearch;
  final String? searchHintText;
  final TextEditingController? controller;

  const AppCustomDropdownWithIcon({
    Key? key,
    required this.items,
    required this.hintText,
    required this.displayText,
    this.value,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.label,
    this.isRequired = false,
    this.enabled = true,
    this.width,
    this.itemIcon,
    this.withSearch = false,
    this.searchHintText,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget dropdown;

    if (withSearch) {
      dropdown = CustomDropdown<T>.search(
        items: items,
        hintText: hintText,
        searchHintText: searchHintText ?? 'Search...',
        onChanged: enabled ? onChanged : null,
        validator: validator,
        initialItem: value,
        enabled: enabled,
        overlayHeight: 300,
        itemsListPadding: EdgeInsets.zero,
        listItemBuilder: (context, item, isSelected, onItemSelect) {
          final icon = itemIcon?.call(item);
          return InkWell(
            onTap: () => onItemSelect?.call(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? kDeepPink.withOpacity(0.08) : Colors.transparent,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    icon,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      displayText(item),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        headerBuilder: (context, selectedItem, enabled) {
          final icon = selectedItem != null ? itemIcon?.call(selectedItem) : null;
          return Row(
            children: [
              if (prefixIcon != null) ...[
                prefixIcon!,
                const SizedBox(width: 12),
              ] else if (icon != null) ...[
                icon,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  selectedItem != null ? displayText(selectedItem) : hintText,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: selectedItem != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          );
        },
        decoration: _buildDecoration(),
      );
    } else {
      dropdown = CustomDropdown<T>(
        items: items,
        hintText: hintText,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        initialItem: value,
        enabled: enabled,
        overlayHeight: 300,
        itemsListPadding: EdgeInsets.zero,
        listItemBuilder: (context, item, isSelected, onItemSelect) {
          final icon = itemIcon?.call(item);
          return InkWell(
            onTap: () => onItemSelect?.call(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? kDeepPink.withOpacity(0.08) : Colors.transparent,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    icon,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      displayText(item),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        headerBuilder: (context, selectedItem, enabled) {
          final icon = selectedItem != null ? itemIcon?.call(selectedItem) : null;
          return Row(
            children: [
              if (prefixIcon != null) ...[
                prefixIcon!,
                const SizedBox(width: 12),
              ] else if (icon != null) ...[
                icon,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  selectedItem != null ? displayText(selectedItem) : hintText,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: selectedItem != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          );
        },
        decoration: _buildDecoration(),
      );
    }

    // Wrap with label if provided
    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label!,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kDeepPink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (width != null) SizedBox(width: width, child: dropdown) else dropdown,
        ],
      );
    }

    // Wrap with width if specified
    if (width != null) {
      return SizedBox(width: width, child: dropdown);
    }

    return dropdown;
  }

  CustomDropdownDecoration _buildDecoration() {
    return CustomDropdownDecoration(
      expandedFillColor: Colors.white,
      closedFillColor: enabled ? Colors.white : Colors.grey.shade50,
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      closedBorder: Border.all(
        color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
        width: 1.5,
      ),
      closedBorderRadius: BorderRadius.circular(12),
      expandedBorder: Border.all(
        color: kDeepPink,
        width: 2,
      ),
      expandedBorderRadius: BorderRadius.circular(12),
      closedSuffixIcon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? kDeepPink : Colors.grey.shade400,
        size: 24,
      ),
      expandedSuffixIcon: Icon(
        Icons.keyboard_arrow_up_rounded,
        color: kDeepPink,
        size: 24,
      ),
    );
  }
}
