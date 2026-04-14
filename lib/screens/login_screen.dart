import 'dart:convert';
import 'dart:io';
import 'dart:async';
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

  // =======================================================
  // NOVO: TESTE DE CONEXÃO RAIO-X
  // =======================================================
  Future<void> _testarConexao() async {
    setState(() => _isLoading = true);
    try {
      // Tentamos bater direto no servidor para ver se a internet deixa passar
      final response = await http.get(
        Uri.parse("https://condologic-backend.onrender.com")
      ).timeout(const Duration(seconds: 15));
      
      _mostrarSucesso("CONEXÃO EXCELENTE!\nO servidor respondeu com sucesso.\nSua internet está liberada para o app.");
    } on SocketException catch (e) {
      _mostrarErroGrave("FALHA CRÍTICA DE INTERNET (SocketException):\n${e.message}\nVerifique se o app tem permissão de dados.");
    } on TimeoutException catch (_) {
      _mostrarErroGrave("SINAL LENTO (Timeout):\nA internet está ativa, mas demorou mais de 15 segundos para alcançar o servidor.");
    } catch (e) {
      _mostrarErroGrave("ERRO DESCONHECIDO:\n$e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
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
        _mostrarErroGrave("Usuário ou Senha inválidos (Erro ${response.statusCode})");
      }
    } catch (e) {
      _mostrarErroGrave("ERRO DE REDE NO LOGIN:\n$e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErroGrave(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Icon(Icons.error_outline, color: Colors.red, size: 50),
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FECHAR", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _mostrarSucesso(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Icon(Icons.wifi, color: Colors.green, size: 50),
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.green)),
          )
        ],
      ),
    );
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
                  const SizedBox(height: 150), 
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
                          const SizedBox(height: 15),
                          // BOTÃO DE DIAGNÓSTICO DE REDE
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _testarConexao,
                              icon: const Icon(Icons.wifi_find, color: Colors.green),
                              label: const Text("TESTAR REDE/SERVIDOR", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.green, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
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