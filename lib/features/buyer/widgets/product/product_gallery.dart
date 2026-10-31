import 'package:flutter/material.dart';

class ProductGallery extends StatefulWidget {
  final String selectedImageUrl;
  final List<String> productImages;
  final int selectedImageIndex;
  final ValueChanged<int> onImageSelected;

  const ProductGallery({
    super.key,
    required this.selectedImageUrl,
    required this.productImages,
    required this.selectedImageIndex,
    required this.onImageSelected,
  });

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  bool _isHoveringMainImage = false;
  Alignment _zoomAlignment = Alignment.center;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Large Main Image Container with Lens Zoom
        MouseRegion(
          cursor: SystemMouseCursors.zoomIn,
          onEnter: (_) {
            setState(() {
              _isHoveringMainImage = true;
            });
          },
          onHover: (event) {
            const containerWidth = 400.0;
            const containerHeight = 400.0;
            final localPos = event.localPosition;
            final alignX = ((localPos.dx / containerWidth) * 2 - 1).clamp(-1.0, 1.0);
            final alignY = ((localPos.dy / containerHeight) * 2 - 1).clamp(-1.0, 1.0);
            setState(() {
              _zoomAlignment = Alignment(alignX, alignY);
            });
          },
          onExit: (_) {
            setState(() {
              _isHoveringMainImage = false;
              _zoomAlignment = Alignment.center;
            });
          },
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHoveringMainImage ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                width: _isHoveringMainImage ? 1.5 : 1.0,
              ),
              boxShadow: _isHoveringMainImage
                  ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Zoomable Image
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: AnimatedAlign(
                        duration: _isHoveringMainImage ? Duration.zero : const Duration(milliseconds: 200),
                        alignment: _zoomAlignment,
                        child: Transform.scale(
                          scale: _isHoveringMainImage ? 2.3 : 1.0,
                          alignment: _zoomAlignment,
                          child: Image.network(
                            widget.selectedImageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF8FAFC)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Discount Badge
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('55% off', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // Zoom Lens Indicator Badge
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isHoveringMainImage ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isHoveringMainImage ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isHoveringMainImage ? Icons.zoom_in : Icons.search,
                            size: 14,
                            color: _isHoveringMainImage ? Colors.white : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isHoveringMainImage ? '2.3x Lens Active' : 'Hover over image to zoom',
                            style: TextStyle(
                              color: _isHoveringMainImage ? Colors.white : const Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expand Icon
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fullscreen, size: 20, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Thumbnail Bar Below Main Image
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(widget.productImages.length, (idx) {
            final isSelected = idx == widget.selectedImageIndex;
            final isLast = idx == widget.productImages.length - 1;

              return Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8.0),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => widget.onImageSelected(idx),
                  child: GestureDetector(
                    onTap: () => widget.onImageSelected(idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 70,
                      width: 80, // Fixed width to prevent stretching
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Image.network(
                            widget.productImages[idx],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F5F9)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
          }),
        ),
      ],
    );
  }
}
