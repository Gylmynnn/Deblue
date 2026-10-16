import 'package:flutter/material.dart';

/// Standard height for trailing controls (button / dropdown / switch)
/// so Scan, All, toggles, etc. all look symmetrical in a row.
const kSettingsControlHeight = 36.0;

/// List density paddings used by Bluetooth / WiFi lists:
/// Comfort = roomy (12), Cozy = balanced (8), Compact = dense (4).
const kComfortListPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
const kCozyListPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
const kCompactListPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// Shared "Obsidian settings" style widgets:
/// - flat dark card with subtle border, radius 12
/// - rows separated by thin dividers
/// - title + muted description on the left, control on the right
/// - small muted button like "Check for updates" / "Open" in the reference.

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _withDividers(context, children),
      ),
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        );
      }
    }
    return out;
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.descriptionWidget,
    required this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final String title;
  final String? description;
  final Widget? descriptionWidget;
  final Widget trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                if (descriptionWidget != null) ...[
                  const SizedBox(height: 4),
                  descriptionWidget!,
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Trailing is shrink-wrapped (no Flexible) so switches,
          // dropdowns, and accent dots all share the same right edge.
          trailing,
        ],
      ),
    );
  }
}

/// Accent button like "Scan" / "Connect" in Bluetooth & WiFi cards.
/// Primary uses the Everblush accent so it matches switches/selections.
/// Set [primary] false for a neutral Everblush button.
class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.enabled = true,
    this.primary = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final neutralBg =
        isDark ? const Color(0xFF2E383C) : const Color(0xFFE8EAED);

    final Color bg;
    final Color fg;
    final Color border;
    if (primary) {
      bg = enabled ? accent : accent.withValues(alpha: 0.35);
      fg = enabled
          ? (ThemeData.estimateBrightnessForColor(accent) == Brightness.light
              ? const Color(0xFF141B1E)
              : Colors.white)
          : (isDark ? const Color(0xFFB3B9B8).withValues(alpha: 0.6) : const Color(0xFF8A9AAA));
      border = enabled
          ? accent.withValues(alpha: 0.6)
          : Colors.transparent;
    } else {
      bg = enabled ? neutralBg : neutralBg.withValues(alpha: 0.5);
      fg = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white : Colors.black);
      border = theme.dividerColor.withValues(alpha: 0.4);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onPressed : null,
        child: Container(
          // minHeight keeps Scan/Connect aligned with switch & dropdown.
          // No alignment here so width stays shrink-wrapped (dropdown
          // broke when alignment made it expand to fill the row).
          constraints:
              const BoxConstraints(minHeight: kSettingsControlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: border,
            ),
            boxShadow: [
              BoxShadow(
                color: primary && enabled
                    ? accent.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: primary && enabled ? 6 : 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muted dropdown-style button (e.g. "English ^v").
class SettingsDropdown<T> extends StatelessWidget {
  const SettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2E383C) : const Color(0xFFE8EAED);

    return Container(
      // minHeight for symmetry with button/switch, but no alignment
      // so width stays shrink-wrapped and right-aligned by SettingsRow.
      constraints: const BoxConstraints(minHeight: kSettingsControlHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          dropdownColor: theme.colorScheme.surface,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Switch with fixed [kSettingsControlHeight] so it aligns symmetrically
/// with [SettingsButton] and [SettingsDropdown] in the same row.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSettingsControlHeight,
      child: Center(
        child: Switch(
          value: value,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Simple device/network row: icon-less, title + subtitle left,
/// action on the right — like a settings list entry.
///
/// [contentPadding] overrides the default padding so callers can implement
/// list density (Comfort / Cozy / Compact) by passing a smaller vertical
/// padding. When null, defaults to Comfort (vertical 12).
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.contentPadding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
