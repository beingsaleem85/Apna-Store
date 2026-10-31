import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

class CheckoutAddressSection extends StatelessWidget {
  final AppStateProvider state;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController altPhoneController;
  final TextEditingController emailController;
  final TextEditingController cityController;
  final TextEditingController townController;
  final TextEditingController addressLineController;
  final TextEditingController landmarkController;
  final TextEditingController postalCodeController;
  final String selectedProvince;
  final String selectedCity;
  final String? selectedAddressId;
  final List<String> provinces;
  final List<String> cities;
  final ValueChanged<String> onProvinceChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<AppAddress> onAddressSelected;

  const CheckoutAddressSection({
    super.key,
    required this.state,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.altPhoneController,
    required this.emailController,
    required this.cityController,
    required this.townController,
    required this.addressLineController,
    required this.landmarkController,
    required this.postalCodeController,
    required this.selectedProvince,
    required this.selectedCity,
    required this.selectedAddressId,
    required this.provinces,
    required this.cities,
    required this.onProvinceChanged,
    required this.onCityChanged,
    required this.onAddressSelected,
  });

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            prefixIcon: prefixText != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Center(
                      widthFactor: 1.0,
                      child: Text(prefixText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('1. Customer & Shipping Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              if (state.addresses.isNotEmpty)
                DropdownButton<String>(
                  value: selectedAddressId,
                  hint: const Text('Select Saved Address', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox(),
                  items: state.addresses.map((a) {
                    return DropdownMenuItem<String>(
                      value: a.id,
                      child: Text('${a.title} (${a.city})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final found = state.addresses.firstWhere((a) => a.id == val);
                      onAddressSelected(found);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'First Name *',
                  controller: firstNameController,
                  hint: 'e.g. Ali',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Last Name *',
                  controller: lastNameController,
                  hint: 'e.g. Khan',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Mobile Number *',
                  controller: phoneController,
                  hint: '03001234567',
                  keyboardType: TextInputType.phone,
                  prefixText: '🇵🇰 +92 ',
                  validator: (v) => v == null || v.trim().length < 10 ? 'Enter valid 11-digit phone' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Alternative Mobile (Optional)',
                  controller: altPhoneController,
                  hint: '03xx-xxxxxxx',
                  keyboardType: TextInputType.phone,
                  prefixText: '💬 ',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTextField(
            label: 'Email Address (For Order Receipts)',
            controller: emailController,
            hint: 'ali.khan@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Province / Territory *',
                  value: selectedProvince,
                  items: provinces,
                  onChanged: onProvinceChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'City *',
                  value: selectedCity,
                  items: cities,
                  onChanged: onCityChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTextField(
            label: 'Complete Street Address (House/Apartment #, Street, Block, Area) *',
            controller: addressLineController,
            hint: 'e.g. House #142, Street 5, Sector F-8/3',
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your shipping address' : null,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Famous Landmark (Optional)',
                  controller: landmarkController,
                  hint: 'e.g. Near Allied Bank',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Postal Code (Optional)',
                  controller: postalCodeController,
                  hint: 'e.g. 54000',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
