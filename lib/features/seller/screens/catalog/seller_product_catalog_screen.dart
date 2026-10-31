import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

class VariantItem {
  final String sku;
  final String color;
  final String size;
  double price;
  int stock;

  VariantItem({
    required this.sku,
    required this.color,
    required this.size,
    required this.price,
    required this.stock,
  });
}

class SellerProductCatalogScreen extends StatefulWidget {
  const SellerProductCatalogScreen({super.key});

  @override
  State<SellerProductCatalogScreen> createState() => _SellerProductCatalogScreenState();
}

class _SellerProductCatalogScreenState extends State<SellerProductCatalogScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&auto=format&fit=crop&q=60');
  final TextEditingController _additionalImagesController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  String _selectedCategory = 'Fashion & Apparel';

  final List<VariantItem> _variants = [
    VariantItem(sku: 'PRD-BLK-S', color: 'Black', size: 'Small', price: 2999.0, stock: 15),
    VariantItem(sku: 'PRD-BLK-M', color: 'Black', size: 'Medium', price: 2999.0, stock: 25),
    VariantItem(sku: 'PRD-RED-L', color: 'Red', size: 'Large', price: 3199.0, stock: 10),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _additionalImagesController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  void _showAddVariantDialog() {
    final colorController = TextEditingController();
    final sizeController = TextEditingController();
    final priceController = TextEditingController(text: '2999');
    final stockController = TextEditingController(text: '20');
    final skuController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product Variant Options'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Color Variation (e.g. Black, Brown, Red, Navy Blue)',
                  hintText: 'Enter color name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sizeController,
                decoration: const InputDecoration(
                  labelText: 'Size Option (e.g. S, M, L, XL, 32, 34, 36)',
                  hintText: 'Enter size value',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuController,
                decoration: const InputDecoration(
                  labelText: 'Unique Variant SKU',
                  hintText: 'e.g. PRD-BLK-32',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (Rs.)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock Units'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (colorController.text.isNotEmpty && sizeController.text.isNotEmpty) {
                setState(() {
                  _variants.add(VariantItem(
                    sku: skuController.text.isNotEmpty ? skuController.text.toUpperCase() : 'SKU-${colorController.text.toUpperCase().substring(0,2)}-${sizeController.text.toUpperCase()}',
                    color: colorController.text.trim(),
                    size: sizeController.text.trim(),
                    price: double.tryParse(priceController.text) ?? 2999.0,
                    stock: int.tryParse(stockController.text) ?? 20,
                  ));
                });
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter both Color and Size!')),
                );
              }
            },
            child: const Text('Add Variant'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog & SKU Generator'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bulk CSV / Excel Upload Header Banner
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bulk Product Upload Studio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Download CSV/Excel template to upload hundreds of products at once.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download Excel Template'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDB913), foregroundColor: Colors.black),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading Product Import Excel Template...')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Single Product Creation Form
            const Text('Single Product Details & Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Product Title (e.g. Unstitched Embroidered Lawn 3-Piece)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: ['Fashion & Apparel', 'Mobiles & Electronics', 'Groceries & Household', 'Home & Living']
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand Name (e.g. Sapphire / Khaadi)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Detailed Product Description & Bullet Points', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            // Multi-Variant SKU Combination Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Multi-Variant SKU Matrix (Color & Size)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Variant Combination'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    _showAddVariantDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _variants.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final v = _variants[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF004D40),
                      radius: 14,
                      child: Text(
                        v.color.isNotEmpty ? v.color[0].toUpperCase() : 'C',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${v.color} - ${v.size} (SKU: ${v.sku})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Price: Rs. ${v.price.toInt()} | Stock: ${v.stock} Units', style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() => _variants.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Media & Size Chart Upload Section
            const Text('Product Media Settings (Images & Video)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Main Product Image URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _additionalImagesController,
              decoration: const InputDecoration(
                labelText: 'Additional Image URLs (Comma-separated list for different angles like front, back, side)',
                hintText: 'e.g. url1, url2, url3',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.photo_library),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                labelText: 'Product Video Showcase URL (Direct MP4 URL)',
                hintText: 'e.g. https://domain.com/video.mp4',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.videocam),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved as Product Draft')));
                  },
                  child: const Text('Save as Draft'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Submit & Make Product Live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: () {
                    if (_titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a product title!')),
                      );
                      return;
                    }
                    
                    final state = Provider.of<AppStateProvider>(context, listen: false);
                    
                    // Generate unique color and size variations from the variant matrix list
                    final colors = _variants.map((v) => v.color).toSet().toList();
                    final sizes = _variants.map((v) => v.size).toSet().toList();

                    final List<ProductVariation> variations = [];
                    if (colors.isNotEmpty) {
                      variations.add(ProductVariation(name: 'Color', values: colors));
                    }
                    if (sizes.isNotEmpty) {
                      variations.add(ProductVariation(name: 'Size', values: sizes));
                    }

                    // Parse additional image URLs
                    final additionalImagesInput = _additionalImagesController.text.trim();
                    final List<String> additionalImages = [];
                    if (additionalImagesInput.isNotEmpty) {
                      additionalImages.addAll(
                        additionalImagesInput
                            .split(',')
                            .map((url) => url.trim())
                            .where((url) => url.isNotEmpty),
                      );
                    }
                    // Ensure the main image is also included as the first thumbnail image
                    final mainImageUrl = _imageUrlController.text.trim().isNotEmpty
                        ? _imageUrlController.text.trim()
                        : 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&auto=format&fit=crop&q=60';
                    
                    if (additionalImages.isEmpty) {
                      additionalImages.add(mainImageUrl);
                    } else if (additionalImages.first != mainImageUrl) {
                      additionalImages.insert(0, mainImageUrl);
                    }

                    if (_titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a product title.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final storeId = state.loggedInSellerId ?? (state.activeSellerStore?.id ?? '');

                    // Create the live AppProduct object
                    final newProduct = AppProduct(
                      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                      sellerId: storeId,
                      name: _titleController.text.trim(),
                      price: _variants.isNotEmpty ? _variants.first.price.toInt().toString() : '2999',
                      description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : '',
                      imageUrl: mainImageUrl,
                      category: _selectedCategory,
                      rating: '0.0',
                      stock: _variants.fold(0, (sum, item) => sum + item.stock),
                      approvalStatus: 'Pending',
                      variations: variations,
                      wholesalePrices: const {},
                      additionalImages: additionalImages,
                      videoUrl: _videoUrlController.text.trim(),
                    );

                    state.addProduct(newProduct);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Product "${newProduct.name}" submitted for approval (Pending).'),
                        backgroundColor: Colors.blue,
                      ),
                    );

                    // Clear form fields
                    _titleController.clear();
                    _descriptionController.clear();
                    _brandController.clear();
                    _imageUrlController.text = 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&auto=format&fit=crop&q=60';
                    _additionalImagesController.clear();
                    _videoUrlController.clear();
                    setState(() {
                      _variants.clear();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
