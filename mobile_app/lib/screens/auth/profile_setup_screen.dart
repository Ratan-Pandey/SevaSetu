import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../user/user_dashboard.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController(); // ✅ NEW
  final _aadhaarController = TextEditingController(); // ✅ NEW
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  XFile? _aadhaarImage; // ✅ Updated type
  DateTime? _selectedDOB; // ✅ NEW
  bool _isLoading = false;

  // ✅ ADD DOB Picker
  Future<void> _selectDOB() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );

    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // ✅ ADD Aadhaar Image Picker
  Future<void> _pickAadhaarImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image != null) {
      setState(() {
        _aadhaarImage = image;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userData != null) {
      _nameController.text = authService.userData!['name'] ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_aadhaarImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Please upload Aadhaar card', Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userId = authService.getUserId();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('User ID not found', Colors.red),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Upload Aadhaar image logic (simulated for now, path would come from backend)
      String? aadhaarPath;
      if (_aadhaarImage != null) {
        // In a real app, we'd upload this file via ApiService and get a path back
        // For now, we'll proceed with the metadata
      }

      final result = await apiService.updateProfile(userId, {
        'name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'dob': _selectedDOB?.toIso8601String(), // ✅ NEW
        'aadhaar_number': _aadhaarController.text.trim(), // ✅ NEW
        'aadhaar_image_path': aadhaarPath, // ✅ NEW
        'profile_completed': true,
      });

      if (!mounted) return;

      if (result != null) {
        authService.updateProfileStatus(true);
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Profile saved successfully!', Colors.green),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Failed to save profile', Colors.red),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Error: $e', Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green ? Icons.check_circle : Icons.error_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667eea).withOpacity(0.1),
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Icon
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_add, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We need some information to get started',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person,
                          validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          validator: (v) => v?.length != 10 ? 'Enter valid 10-digit number' : null,
                        ),
                        const SizedBox(height: 18),
                        // Date of Birth Field
                        _buildTextField(
                          controller: _dobController,
                          label: 'Date of Birth (DOB) *',
                          icon: Icons.calendar_today,
                          hintText: 'DD/MM/YYYY',
                          readOnly: true,
                          onTap: _selectDOB,
                          validator: (v) => v?.isEmpty ?? true ? 'Date of Birth is required' : null,
                        ),
                        const SizedBox(height: 18),
                        // Aadhaar Number Field
                        _buildTextField(
                          controller: _aadhaarController,
                          label: 'Aadhaar Number *',
                          icon: Icons.credit_card,
                          hintText: 'XXXX XXXX XXXX',
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Aadhaar is required';
                            if (v.length != 12) return 'Must be 12 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        // Aadhaar Upload
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Aadhaar Card (Front) *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_aadhaarImage != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.network(_aadhaarImage!.path, height: 150, width: double.infinity, fit: BoxFit.cover)
                                      : Image.network(_aadhaarImage!.path, height: 150, width: double.infinity, fit: BoxFit.cover), // path is fine on mobile too for XFile
                                ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _pickAadhaarImage,
                                icon: const Icon(Icons.upload_file),
                                label: Text(_aadhaarImage == null ? 'Choose Image' : 'Change Image'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Complete Address *',
                          icon: Icons.location_on,
                          hintText: 'House No., Street, City, State, PIN',
                          maxLines: 3,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Address is required';
                            if (v.trim().length < 20) return 'Please enter complete address';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _cityController,
                                label: 'City',
                                icon: Icons.location_city,
                                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _pincodeController,
                                label: 'Pincode',
                                icon: Icons.pin_drop,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                validator: (v) => v?.length != 6 ? 'Invalid' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: _stateController,
                          label: 'State',
                          icon: Icons.map,
                          validator: (v) => v?.trim().isEmpty ?? true ? 'State is required' : null,
                        ),
                        const SizedBox(height: 32),
                        
                        // Submit Button with Gradient
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save and Continue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: const Color(0xFF667eea)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          counterText: '',
          suffixIcon: onTap != null ? IconButton(icon: const Icon(Icons.edit_calendar, color: Color(0xFF667eea)), onPressed: onTap) : null,
        ),
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _aadhaarController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }
}