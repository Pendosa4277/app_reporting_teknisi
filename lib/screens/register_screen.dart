import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _selectedRole = 'technician';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Show loading
      _showLoading();

      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Sign up user
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': _selectedRole},
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      if (res.user == null) {
        _showError('Gagal mendaftar: Akun tidak dapat dibuat');
        return;
      }

      // Create profile
      await supabase.from('profiles').insert({
        'id': res.user!.id,
        'email': email,
        'role': _selectedRole,
      });

      if (!mounted) return;

      // Show success message and return to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pendaftaran berhasil! Silakan cek email untuk konfirmasi.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;

      String message = err is AuthException
          ? _getAuthErrorMessage(err.message)
          : 'Gagal mendaftar: ${err.toString()}';

      _showError(message);
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getAuthErrorMessage(String code) => switch (code) {
    'User already registered' => 'Email sudah terdaftar',
    'Invalid email' => 'Format email tidak valid',
    'Weak password' => 'Password terlalu lemah',
    _ => code,
  };

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buat Akun Baru',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Masukkan email anda',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Email tidak boleh kosong'
                      : !v.contains('@') || !v.contains('.')
                      ? 'Masukkan email yang valid'
                      : null,
                  onChanged: (_) {
                    // Reset form errors on change
                    _formKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'technician',
                      child: Text('Teknisi'),
                    ),
                    DropdownMenuItem(
                      value: 'supervisor',
                      child: Text('Supervisor'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedRole = v ?? 'technician'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    hintText: 'Minimal 6 karakter',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Password tidak boleh kosong'
                      : v.length < 6
                      ? 'Password minimal 6 karakter'
                      : null,
                  onChanged: (_) {
                    // Revalidate confirm password when password changes
                    _formKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: 'Masukkan password kembali',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Konfirmasi password diperlukan'
                      : v != _passwordController.text
                      ? 'Password tidak cocok'
                      : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'DAFTAR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
