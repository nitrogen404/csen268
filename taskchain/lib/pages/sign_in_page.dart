import 'package:flutter/material.dart';
import '../main.dart'; // for navIndex

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ListView(
            children: [
              const SizedBox(height: 80),

              // App logo and tagline
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7B61FF), Color(0xFFFF6EC7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.link_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text("TaskChain",
                      style: text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text("Small steps. Strong chains.",
                      style: text.bodyMedium?.copyWith(color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 50),

              // Social sign-in
              _socialButton(
                icon: Icons.language_rounded,
                label: "Continue with Google",
                onPressed: () => _goToHome(context),
              ),
              const SizedBox(height: 14),
              _socialButton(
                icon: Icons.apple,
                label: "Continue with Apple",
                onPressed: () => _goToHome(context),
              ),

              const SizedBox(height: 30),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider(thickness: 1)),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text("or", style: text.bodySmall),
                  ),
                  const Expanded(child: Divider(thickness: 1)),
                ],
              ),

              const SizedBox(height: 30),

              // Email input
              Text("Email",
                  style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: "you@example.com",
                  filled: true,
                  fillColor: cs.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Password input
              Text("Password",
                  style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "••••••••",
                  filled: true,
                  fillColor: cs.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Sign In button
              ElevatedButton.icon(
                onPressed: () => _goToHome(context),
                icon: const Icon(Icons.mail_outline),
                label: const Text("Sign In"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB49BFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Sign up prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don’t have an account? "),
                  GestureDetector(
                    onTap: () => _showSignUpDialog(context),
                    child: Text("SIGN UP",
                        style: TextStyle(
                            color: cs.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.black87),
      label: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black87)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSignUpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Sign Up"),
        content: const Text("This is a placeholder for the sign-up flow."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _goToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) {
        navIndex.value = 0;
        return const RootShell();
      }),
    );
  }
}
