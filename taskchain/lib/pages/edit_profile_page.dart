import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: "Alex Johnson");
  final _emailController = TextEditingController(text: "alex.johnson@email.com");
  final _bioController = TextEditingController(text: "Tell us about yourself...");
  final _locationController = TextEditingController(text: "San Francisco, CA");
  final CameraService _cameraService = CameraService();
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final path = await _cameraService.getSavedProfileImagePath();
    if (mounted) setState(() => _profileImagePath = path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Edit Profile", style: TextStyle(color: Colors.black)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar picker
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _takePhoto,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFFFFC72C),
                        backgroundImage: _profileImagePath != null
                            ? FileImage(File(_profileImagePath!))
                            : null,
                        child: _profileImagePath == null
                            ? const Text('AJ', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt_outlined),
                                  title: const Text('Take Photo'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _takePhoto();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library_outlined),
                                  title: const Text('Choose From Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickFromGallery();
                                  },
                                ),
                                if (_profileImagePath != null)
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: const Text('Remove Photo'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _cameraService.clearSavedProfileImage();
                                      if (mounted) setState(() => _profileImagePath = null);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Change Photo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // PERSONAL INFO SECTION
              _sectionCard(
                title: "Personal Information",
                child: Column(
                  children: [
                    _textField("Full Name", _nameController),
                    const SizedBox(height: 12),
                    _textField("Email", _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _textField(
                      "Bio",
                      _bioController,
                      maxLines: 3,
                      showCounter: true,
                      maxLength: 150,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // LOCATION SECTION
              _sectionCard(
                title: "Location",
                child: _textField("City, State/Country", _locationController),
              ),
              const SizedBox(height: 16),
              // ACCOUNT INFO SECTION
              _sectionCard(
                title: "Account Information",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Member Since",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Account creation date cannot be changed",
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                      ),
                      onPressed: _saveChanges,
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF9C27F0), Color(0xFF7E4DF9)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          height: 48,
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------- UI HELPERS --------------

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool showCounter = false,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        counterText: showCounter ? null : "",
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF7F5FB),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
          borderSide: const BorderSide(color: Color(0xFF9C27F0)),
        ),
      ),
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
    }
  }

  Future<void> _takePhoto() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening camera...')));
    try {
      final path = await _cameraService.takePictureAndSave();
      if (path != null && mounted) {
        setState(() {
          _profileImagePath = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo saved')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No photo captured')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening gallery...')));
    try {
      final path = await _cameraService.pickFromGalleryAndSave();
      if (path != null && mounted) {
        setState(() {
          _profileImagePath = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo saved')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No image selected')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }
}

