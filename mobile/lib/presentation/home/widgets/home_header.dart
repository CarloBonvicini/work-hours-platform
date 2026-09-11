// Intestazione della home con navigazione tra sezioni.

import 'package:flutter/material.dart';
import 'package:work_hours_mobile/presentation/home/models/home_section.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.selectedSection,
    required this.hasCloudAccount,
    required this.unreadTicketReplyCount,
    required this.onSelectSection,
    required this.onOpenRegistration,
  });

  final HomeSection selectedSection;
  final bool hasCloudAccount;
  final int unreadTicketReplyCount;
  final ValueChanged<HomeSection> onSelectSection;
  final VoidCallback onOpenRegistration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCloudWarning =
        selectedSection == HomeSection.workSettings && !hasCloudAccount;
    final navigationButtons = List<Widget>.generate(
      mainNavigationSections.length,
      (index) {
        final section = mainNavigationSections[index];
        return Padding(
          padding: EdgeInsets.only(
            right: index < mainNavigationSections.length - 1 ? 10 : 0,
          ),
          child: HomeHeaderSectionIconButton(
            section: section,
            isSelected: selectedSection == section,
            badgeCount: section == HomeSection.ticket
                ? unreadTicketReplyCount
                : 0,
            onTap: () => onSelectSection(section),
          ),
        );
      },
      growable: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('navigation-menu-button'),
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(width: 1, height: 1),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: navigationButtons,
                  ),
                ),
              ),
            );
          },
        ),
        if (showCloudWarning) ...[
          const SizedBox(height: 10),
          Text(
            'Le impostazioni si perdono se non crei un account.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onOpenRegistration,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Registrati'),
          ),
        ],
      ],
    );
  }
}

class HomeHeaderSectionIconButton extends StatelessWidget {
  const HomeHeaderSectionIconButton({
    super.key,
    required this.section,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final HomeSection section;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: section.label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: IconButton.filledTonal(
              key: ValueKey(legacyNavigationOptionKey(section)),
              onPressed: onTap,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.20)
                    : theme.colorScheme.surfaceContainerLow,
                foregroundColor: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              icon: Icon(section.icon, size: 20),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
