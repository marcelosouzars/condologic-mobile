import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _verificarSessaoAtiva();
  }

  Future<void> _verificarSessaoAtiva() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_session');
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(user: userData)),
      );
    }
  }

  Future<void> _fazerLogin() async {
    String cpf = _cpfController.text.trim();
    String senha = _passController.text.trim();

    if (cpf.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe CPF e Senha")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://condologic-backend.onrender.com/api/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cpf": cpf, "senha": senha}),
      ).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(userData));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(user: userData)),
        );
      } else {
        _mostrarErro("Usuário ou Senha inválidos");
      }
    } catch (e) {
      _mostrarErro("Erro de conexão. Verifique sua internet.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_mobile.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Color(0xa0000000), BlendMode.srcOver), 
              child: const SizedBox(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  Icon(Icons.apartment, size: 70, color: Colors.blue[100]), 
                  const SizedBox(height: 10),
                  Text(
                    "CONDOLOGIC",
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.blue[100], 
                      letterSpacing: 2
                    ),
                  ),
                  const Text(
                    "SISTEMA DE FOTOMETRIA", 
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 220), 
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Acesse sua Conta",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _cpfController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "CPF (Apenas números)",
                              prefixIcon: Icon(Icons.person, color: Colors.blue[900], size: 20),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "SENHA",
                              prefixIcon: Icon(Icons.lock, color: Colors.blue[900], size: 20),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _fazerLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[900],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("ENTRAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}