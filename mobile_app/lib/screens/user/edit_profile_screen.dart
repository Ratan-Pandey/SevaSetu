import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const EditProfileScreen({super.key, this.initialData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // 🔥 PREFILL CONTROLLERS
    final data = widget.initialData;
    _nameController = TextEditingController(text: data?['name'] ?? '');
    _phoneController = TextEditingController(text: data?['phone_number'] ?? '');
    _addressController = TextEditingController(text: data?['address'] ?? '');
    _cityController = TextEditingController(text: data?['city'] ?? '');
    _stateController = TextEditingController(text: data?['state'] ?? '');
    _pincodeController = TextEditingController(text: data?['pincode'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userId = authService.getUserId();

    if (userId == null) return;

    try {
      final success = await apiService.updateProfile(userId, {
        'name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
      });

      if (success != null && mounted) {
        // 🔥 STEP 1: Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', _nameController.text.trim());
        await prefs.setString('phone_number', _phoneController.text.trim());

        // Refresh local data in AuthService
        await authService.loadUserData();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        
        // 🔥 STEP 2: Return success to ProfileScreen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildField(_nameController, 'Full Name', Icons.person),
              const SizedBox(height: 16),
              _buildField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildField(_addressController, 'Address', Icons.location_on, maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField(_cityController, 'City', Icons.location_city)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField(_pincodeController, 'Pincode', Icons.pin_drop, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              _buildField(_stateController, 'State', Icons.map),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: const Color(0xFF667eea).withOpacity(0.4),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
          ),
        ),
        validator: (v) => v?.trim().isEmpty ?? true ? '$label is required' : null,
      ),
    );
  }
}
