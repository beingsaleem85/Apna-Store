import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/feature_flags.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/supabase_checkout_service.dart';
import 'package:apna_store/core/widgets/app_footer.dart';
import '../../widgets/checkout/checkout_action_bar.dart';
import '../../widgets/checkout/checkout_address_section.dart';
import '../../widgets/checkout/checkout_order_summary.dart';
import '../../widgets/checkout/checkout_payment_selector.dart';
import '../../widgets/checkout/checkout_price_breakdown.dart';

class BuyerCheckoutScreen extends StatefulWidget {
  const BuyerCheckoutScreen({super.key});

  @override
  State<BuyerCheckoutScreen> createState() => _BuyerCheckoutScreenState();
}

class _BuyerCheckoutScreenState extends State<BuyerCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _altPhoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedProvince = 'Punjab';
  String _selectedCity = 'Lahore';
  final TextEditingController _cityController = TextEditingController(text: 'Lahore');
  final TextEditingController _townController = TextEditingController();
  final TextEditingController _addressLineController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  String _selectedPaymentMethod = 'COD';
  final int _couponDiscount = 0;

  bool _isProcessing = false;
  String? _selectedAddressId;

  final List<String> _provinces = ['Punjab', 'Sindh', 'Khyber Pakhtunkhwa', 'Balochistan', 'Islamabad Capital Territory', 'Gilgit-Baltistan', 'Azad Kashmir'];
  final List<String> _cities = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar', 'Quetta', 'Sialkot', 'Gujranwala', 'Hyderabad', 'Sukkur', 'Abbottabad', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
      final state = Provider.of<AppStateProvider>(context, listen: false);
      if (state.addresses.isNotEmpty) {
        final def = state.addresses.firstWhere((a) => a.isDefault, orElse: () => state.addresses.first);
        _applyAddress(def);
      }
    });
  }

  void _applyAddress(AppAddress addr) {
    setState(() {
      _selectedAddressId = addr.id;
      _cityController.text = addr.city;
      if (_cities.contains(addr.city)) {
        _selectedCity = addr.city;
      }
      _townController.text = addr.unionCouncil;
      _addressLineController.text = addr.addressLine;
      _landmarkController.text = addr.landmark;
      _postalCodeController.text = addr.postalCode;
      if (addr.province.isNotEmpty && _provinces.contains(addr.province)) {
        _selectedProvince = addr.province;
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _townController.dispose();
    _addressLineController.dispose();
    _landmarkController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    if (_firstNameController.text.trim().isEmpty) return false;
    if (_lastNameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().length < 10) return false;
    if (_cityController.text.trim().isEmpty) return false;
    if (_addressLineController.text.trim().isEmpty) return false;
    if (_emailController.text.isNotEmpty && !_emailController.text.contains('@')) return false;
    return true;
  }

  void _handlePlaceOrder(AppStateProvider state) async {
    if (!_formKey.currentState!.validate() || !_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields marked with * correctly.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    if (state.cartProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty! Add products before checking out.')),
      );
      return;
    }

    if (!FeatureFlags.onlinePaymentsEnabled && _selectedPaymentMethod != 'COD') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Online payments are not available yet. Please select Cash on Delivery.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final String buyerFullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    final String idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}_${state.cartProducts.length}';
    final cartList = List<AppProduct>.from(state.cartProducts);
    final itemsPayload = cartList.map((p) => {'product_id': p.id, 'quantity': 1}).toList();

    try {
      final res = await SupabaseCheckoutService().checkout(
        idempotencyKey: idempotencyKey,
        items: itemsPayload,
        shippingAddress: {
          'recipient_name': buyerFullName,
          'phone': _phoneController.text.trim(),
          'address_line': _addressLineController.text.trim(),
          'city': _cityController.text.trim(),
          'province': _selectedProvince,
        },
        paymentMethod: _selectedPaymentMethod,
      );

      final String orderId = (res['order_number'] ?? '').toString();
      final num grandTotalVal = res['grand_total'] ?? 0;

      state.clearCart();
      await state.ordersController.fetchOrdersFromSupabase();

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacementNamed(
          context,
          '/buyer/order-success',
          arguments: {
            'orderId': orderId,
            'buyerName': buyerFullName,
            'itemCount': cartList.length,
            'grandTotal': grandTotalVal,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);

    final Map<String, int> grouped = {};
    for (final p in state.cartProducts) {
      grouped[p.id] = (grouped[p.id] ?? 0) + 1;
    }

    final List<AppProduct> uniqueProducts = [];
    for (final id in grouped.keys) {
      final found = state.cartProducts.firstWhere((p) => p.id == id);
      uniqueProducts.add(found);
    }

    final int subtotal = state.cartProducts.fold(0, (sum, p) => sum + (int.tryParse(p.price.replaceAll(',', '')) ?? 0));
    final int shippingFee = uniqueProducts.isEmpty ? 0 : 150;
    final int grandTotal = (subtotal + shippingFee - _couponDiscount).clamp(0, 999999);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                            tooltip: 'Back to Previous Page',
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushReplacementNamed(context, '/');
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => Navigator.pushReplacementNamed(context, '/'),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Elegant Marketplace',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          Icon(Icons.lock_rounded, color: Color(0xFF059669), size: 18),
                          SizedBox(width: 6),
                          Text(
                            '100% SECURE CHECKOUT',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/'),
                        child: const Text('Home', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      const Text('  /  ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/buyer/cart'),
                        child: const Text('Shopping Cart', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      const Text('  /  ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const Text('Checkout & Payment', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 850;

                      if (!isDesktop) {
                        return Column(
                          children: [
                            CheckoutAddressSection(
                              state: state,
                              firstNameController: _firstNameController,
                              lastNameController: _lastNameController,
                              phoneController: _phoneController,
                              altPhoneController: _altPhoneController,
                              emailController: _emailController,
                              cityController: _cityController,
                              townController: _townController,
                              addressLineController: _addressLineController,
                              landmarkController: _landmarkController,
                              postalCodeController: _postalCodeController,
                              selectedProvince: _selectedProvince,
                              selectedCity: _selectedCity,
                              selectedAddressId: _selectedAddressId,
                              provinces: _provinces,
                              cities: _cities,
                              onProvinceChanged: (p) => setState(() => _selectedProvince = p),
                              onCityChanged: (c) => setState(() => _selectedCity = c),
                              onAddressSelected: _applyAddress,
                            ),
                            const SizedBox(height: 20),
                            CheckoutOrderSummary(
                              uniqueProducts: uniqueProducts,
                              groupedQuantities: grouped,
                            ),
                            const SizedBox(height: 20),
                            CheckoutPaymentSelector(
                              selectedPaymentMethod: _selectedPaymentMethod,
                              onPaymentMethodChanged: (m) => setState(() => _selectedPaymentMethod = m),
                            ),
                            const SizedBox(height: 20),
                            CheckoutPriceBreakdown(
                              subtotal: subtotal,
                              shippingFee: shippingFee,
                              couponDiscount: _couponDiscount,
                              grandTotal: grandTotal,
                            ),
                            const SizedBox(height: 20),
                            CheckoutActionBar(
                              isProcessing: _isProcessing,
                              onPlaceOrder: () => _handlePlaceOrder(state),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CheckoutAddressSection(
                                  state: state,
                                  firstNameController: _firstNameController,
                                  lastNameController: _lastNameController,
                                  phoneController: _phoneController,
                                  altPhoneController: _altPhoneController,
                                  emailController: _emailController,
                                  cityController: _cityController,
                                  townController: _townController,
                                  addressLineController: _addressLineController,
                                  landmarkController: _landmarkController,
                                  postalCodeController: _postalCodeController,
                                  selectedProvince: _selectedProvince,
                                  selectedCity: _selectedCity,
                                  selectedAddressId: _selectedAddressId,
                                  provinces: _provinces,
                                  cities: _cities,
                                  onProvinceChanged: (p) => setState(() => _selectedProvince = p),
                                  onCityChanged: (c) => setState(() => _selectedCity = c),
                                  onAddressSelected: _applyAddress,
                                ),
                                const SizedBox(height: 20),
                                CheckoutOrderSummary(
                                  uniqueProducts: uniqueProducts,
                                  groupedQuantities: grouped,
                                ),
                                const SizedBox(height: 20),
                                CheckoutPaymentSelector(
                                  selectedPaymentMethod: _selectedPaymentMethod,
                                  onPaymentMethodChanged: (m) => setState(() => _selectedPaymentMethod = m),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),

                          Expanded(
                            flex: 35,
                            child: Column(
                              children: [
                                CheckoutPriceBreakdown(
                                  subtotal: subtotal,
                                  shippingFee: shippingFee,
                                  couponDiscount: _couponDiscount,
                                  grandTotal: grandTotal,
                                ),
                                const SizedBox(height: 20),
                                CheckoutActionBar(
                                  isProcessing: _isProcessing,
                                  onPlaceOrder: () => _handlePlaceOrder(state),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
