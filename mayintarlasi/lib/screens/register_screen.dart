import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _message; // Mesaj metni
  bool _isSuccess = false; // Başarı mı, hata mı?

  // Şifre kurallarını kontrol eden yardımcı fonksiyon
  bool isPasswordValid(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final isLongEnough = password.length >= 8;
    return hasUppercase && hasLowercase && hasDigit && isLongEnough;
  }

  Future<void> _registerUser() async {
    setState(() {
      _message = null;
    });

    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // Şifre geçerlilik kontrolü
    if (!isPasswordValid(password)) {
      setState(() {
        _message = "Şifre en az 8 karakter olmalı, büyük harf, küçük harf ve rakam içermelidir.";
        _isSuccess = false;
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _message = "Bu kullanıcı adı zaten alınmış.";
          _isSuccess = false;
        });
        return;
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _message = "Kayıt başarılı! Giriş yaparak devam edebilirsiniz.";
        _isSuccess = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kayıt başarılı!"))
      );

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _isSuccess = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Bir hata oluştu.";
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kayıt Ol")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Kullanıcı Adı"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "E-posta"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Şifre"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _registerUser();
              },
              child: const Text("Kayıt Ol"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("Zaten hesabın var mı? Giriş yap"),
            ),
          ],
        ),
      ),
    );
  }
}
