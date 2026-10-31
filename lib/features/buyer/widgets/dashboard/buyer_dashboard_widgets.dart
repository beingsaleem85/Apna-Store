import 'package:flutter/material.dart';

class HoverNavCategoryLink extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const HoverNavCategoryLink({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.isSelected,
  });

  @override
  State<HoverNavCategoryLink> createState() => _HoverNavCategoryLinkState();
}

class _HoverNavCategoryLinkState extends State<HoverNavCategoryLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF005C53);
    final active = widget.isSelected || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? greenColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: active ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 6),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverLiftCategoryCircle extends StatefulWidget {
  final String title;
  final String imageUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool isSpecial;

  const HoverLiftCategoryCircle({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.onTap,
    this.isSpecial = false,
  });

  @override
  State<HoverLiftCategoryCircle> createState() => _HoverLiftCategoryCircleState();
}

class _HoverLiftCategoryCircleState extends State<HoverLiftCategoryCircle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? (Matrix4.identity()..translate(0, -8, 0)) : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isHovered ? 0.15 : 0.05),
                    blurRadius: _isHovered ? 12 : 6,
                    offset: Offset(0, _isHovered ? 6 : 3),
                  )
                ],
              ),
              child: ClipOval(
                child: widget.imageUrl.isNotEmpty
                    ? Image.network(
                        widget.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(widget.fallbackIcon, color: const Color(0xFF005C53)),
                      )
                    : Icon(widget.fallbackIcon, color: const Color(0xFF005C53), size: 30),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: widget.isSpecial ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopUtilityNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const TopUtilityNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<TopUtilityNavItem> createState() => _TopUtilityNavItemState();
}

class _TopUtilityNavItemState extends State<TopUtilityNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: _isHovered ? const Color(0xFF004D40) : const Color(0xFF475569)),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? const Color(0xFF004D40) : const Color(0xFF475569),
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeroCtaButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const HeroCtaButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  State<HeroCtaButton> createState() => _HeroCtaButtonState();
}

class _HeroCtaButtonState extends State<HeroCtaButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isHovered ? const Color(0xFF004D40) : const Color(0xFFFDB913),
          foregroundColor: _isHovered ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: _isHovered ? 4 : 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class ViewAllHeaderButton extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const ViewAllHeaderButton({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  State<ViewAllHeaderButton> createState() => _ViewAllHeaderButtonState();
}

class _ViewAllHeaderButtonState extends State<ViewAllHeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Row(
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _isHovered ? const Color(0xFF004D40) : const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _isHovered ? const Color(0xFF004D40) : const Color(0xFF0F766E),
            ),
          ],
        ),
      ),
    );
  }
}

class MegaMenuItemWidget extends StatefulWidget {
  final String title;
  final List<String> subItems;
  final ValueChanged<String> onSelectSubItem;

  const MegaMenuItemWidget({
    super.key,
    required this.title,
    required this.subItems,
    required this.onSelectSubItem,
  });

  @override
  State<MegaMenuItemWidget> createState() => _MegaMenuItemWidgetState();
}

class _MegaMenuItemWidgetState extends State<MegaMenuItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.subItems
                  .map((sub) => InkWell(
                        onTap: () => widget.onSelectSubItem(sub),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            sub,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
