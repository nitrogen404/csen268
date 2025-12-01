import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  final _authService = AuthService();
  final _userService = UserService();
  final _picker = ImagePicker();

  bool _loading = true;
  File? _selectedImage;
  String? _currentProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildProfilePictureSection(),
                    const SizedBox(height: 20),
                    _sectionCard(
                      title: "Personal Information",
                      child: Column(
                        children: [
                          _textField("Full Name", _nameController),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Email",
                              labelStyle:
                                  const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF7F5FB),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF9C27F0)),
                              ),
                            ),
                          ),
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
                    _sectionCard(
                      title: "Location",
                      child:
                          _textField("City, State/Country", _locationController),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: "Account Information",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Member Since",
                            style:
                                TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Account creation date cannot be changed",
                            style: TextStyle(
                                color: Colors.black54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ).copyWith(
                              backgroundColor:
                                  WidgetStateProperty.all(Colors.transparent),
                            ),
                            onPressed: _saveChanges,
                            child: Ink(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF9C27F0),
                                    Color(0xFF7E4DF9)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
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

  Widget _buildProfilePictureSection() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    // Generate initials for fallback
    String initials = '?';
    final displayName = _nameController.text.trim();
    if (displayName.isNotEmpty) {
      final parts = displayName.split(' ');
      if (parts.length == 1) {
        initials = parts.first.substring(0, 1).toUpperCase();
      } else {
        initials = (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
      }
    }

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFFFC72C),
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!) as ImageProvider
                    : (_currentProfilePictureUrl != null && _currentProfilePictureUrl!.isNotEmpty
                        ? NetworkImage(_currentProfilePictureUrl!)
                        : null),
                child: (_selectedImage == null && 
                       (_currentProfilePictureUrl == null || _currentProfilePictureUrl!.isEmpty))
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27F0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    onSelected: (value) {
                      if (value == 'camera') {
                        _pickImage(fromCamera: true);
                      } else if (value == 'gallery') {
                        _pickImage(fromCamera: false);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'camera',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.black87),
                            SizedBox(width: 12),
                            Text('Take Photo'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'gallery',
                        child: Row(
                          children: [
                            Icon(Icons.photo_library, color: Colors.black87),
                            SizedBox(width: 12),
                            Text('Choose from Gallery'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap camera icon to change photo',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be signed in to update profile")),
      );
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Updating profile...")),
        );
      }

      String? profilePictureUrl;

      // Upload new profile picture if selected
      if (_selectedImage != null) {
        profilePictureUrl = await _userService.uploadProfilePicture(
          userId: user.uid,
          imageFile: _selectedImage!,
        );
      }

      // Update profile with all information
      await _userService.updateProfile(
        userId: user.uid,
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        profilePictureUrl: profilePictureUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e")),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _userService.getUserProfile(user.uid);
      final data = (doc.data() ?? <String, dynamic>{});

      _nameController.text =
          data['displayName'] as String? ?? (user.email ?? 'TaskChain User');

      _emailController.text = user.email ?? '';

      _bioController.text = data['bio'] as String? ?? '';
      _locationController.text = data['location'] as String? ?? '';
      _currentProfilePictureUrl = data['profilePictureUrl'] as String?;
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}