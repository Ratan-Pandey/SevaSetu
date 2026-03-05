import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'complaint_success_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import '../../services/location_service.dart';
import '../../services/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class ComplaintFormScreen extends StatefulWidget {
  final String department;

  const ComplaintFormScreen({super.key, required this.department});

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  bool _isSubmitting = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _locationData;
  bool _fetchingLocation = false;
  
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordedAudioPath;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  Future<void> _getLocation() async {
    setState(() => _fetchingLocation = true);
    final locationService = LocationService();
    final location = await locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _locationData = location;
        _fetchingLocation = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      print('Image picker error: $e');
    }
  }

  Future<bool> _uploadImage(int complaintId) async {
    if (_selectedImage == null) return true;
    
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/complaints/$complaintId/upload-image'),
      );
      
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        _selectedImage!.path,
        contentType: MediaType('image', 'jpeg'), // Best effort for common images
      ));
      
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  Future<void> _startRecording() async {
    final started = await _audioService.startRecording();
    if (started) {
      if (mounted) setState(() => _isRecording = true);
      _startRecordingTimer();
    }
  }

  void _startRecordingTimer() {
    _recordingDuration = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _recordingDuration++);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioService.stopRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
    }
  }

  Future<void> _playAudio() async {
    if (_recordedAudioPath != null) {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordedAudioPath != null) {
      final file = File(_recordedAudioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (mounted) setState(() => _recordedAudioPath = null);
  }

  Future<bool> _uploadAudio(int complaintId) async {
    if (_recordedAudioPath == null) return true;
    
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/complaints/$complaintId/upload-audio'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', _recordedAudioPath!),
      );
      
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Audio upload error: $e');
      return false;
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userId = authService.getUserId();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Please login first', Colors.red),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final result = await apiService.submitComplaint(
      userId,
      _complaintController.text.trim(),
      widget.department,
      latitude: _locationData?['latitude'],
      longitude: _locationData?['longitude'],
      locationAddress: _locationData?['address'],
    );

    if (!mounted) return;

    if (result != null) {
      // Upload image if selected
      if (_selectedImage != null) {
        await _uploadImage(result['id']);
      }

      // Upload audio if recorded
      if (_recordedAudioPath != null) {
        await _uploadAudio(result['id']);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintSuccessScreen(
            trackingId: result['tracking_id'],
            complaintData: result,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Failed to submit complaint', Colors.red),
      );
      setState(() => _isSubmitting = false);
    }
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white),
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
              const Color(0xFF667eea).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Submit Complaint',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Department Badge
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.business,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Department',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.department,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tips Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Tips for better complaint',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTip('Describe the issue clearly in English'),
                              _buildTip('Include specific location details'),
                              _buildTip('Mention urgency if critical'),
                              _buildTip('AI will automatically analyze and categorize'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Complaint Text Field
                        Container(
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
                            controller: _complaintController,
                            decoration: InputDecoration(
                              labelText: 'Describe your complaint *',
                              hintText: 'Example: No electricity for three days in my area. Emergency situation...',
                              alignLabelWithHint: true,
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
                                borderSide: const BorderSide(
                                  color: Color(0xFF667eea),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              counterText: '',
                            ),
                            maxLines: 8,
                            maxLength: 500,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please describe your complaint';
                              }
                              if (value.trim().length < 20) {
                                return 'Please provide more details (minimum 20 characters)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Image Selection UI
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Add Photo Evidence (Optional)', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              if (_selectedImage != null) ...[
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(_selectedImage!, 
                                        height: 200, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.white,
                                        child: IconButton(
                                          onPressed: () => setState(() => _selectedImage = null),
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _pickImage(ImageSource.gallery),
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text('Gallery'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _pickImage(ImageSource.camera),
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Camera'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Location Selection UI
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Location (Optional)', 
                                style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              if (_locationData != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _locationData!['address'],
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(() => _locationData = null),
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Remove'),
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: _fetchingLocation ? null : _getLocation,
                                  icon: _fetchingLocation
                                      ? const SizedBox(width: 16, height: 16, 
                                          child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.my_location),
                                  label: Text(_fetchingLocation ? 'Getting location...' : 'Get Current Location'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // AI Badge
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.smart_toy,
                                color: Colors.purple.shade700,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'AI will analyze and predict category, urgency, and delay risk',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        Container(
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
                            onPressed: _isSubmitting ? null : _submitComplaint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text(
                                        'Submit Complaint',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
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

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _audioService.dispose();
    super.dispose();
  }
}