import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    String cpf = _cpfController.text.trim();
    String senha = _passController.text.trim();

    if (cpf.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe CPF e Senha")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Tempo limite de 60 segundos para o Render "acordar"
      final response = await http.post(
        Uri.parse("https://condologic-backend.onrender.com/api/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cpf": cpf, "senha": senha}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(user: userData)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuário ou Senha inválidos", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro de conexão: O servidor demorou a responder ou está offline.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. CAMADA DE IMAGEM DE FUNDO
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_mobile.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // 2. CAMADA DE PELÍCULA ESCURA
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Color(0xa0000000), BlendMode.srcOver), 
              child: const SizedBox(),
            ),
          ),

          // 3. CAMADA DE CONTEÚDO 
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  // LOGO FLUTUANTE NO TOPO
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
                    style: TextStyle(
                      color: Colors.white70, 
                      fontSize: 11, 
                      fontWeight: FontWeight.bold
                    )
                  ),

                  // ESPAÇO VAZIO AUMENTADO PARA EMPURRAR O LOGIN BEM PARA BAIXO
                  const SizedBox(height: 220), 

                  // CARD DE LOGIN (MAIS COMPACTO)
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      // Reduzimos o preenchimento interno para a caixa ficar menor
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Acesse sua Conta",
                            style: TextStyle(
                              fontSize: 16, // Fonte menor
                              fontWeight: FontWeight.bold, 
                              color: Colors.blue[900]
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // CAMPO CPF MAIS FINO
                          TextField(
                            controller: _cpfController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14), // Letra menor ao digitar
                            decoration: InputDecoration(
                              labelText: "CPF (Apenas números)",
                              labelStyle: const TextStyle(fontSize: 14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              isDense: true, // Achata o campo
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.person, color: Colors.blue[900], size: 20), // Ícone menor
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // CAMPO SENHA MAIS FINO
                          TextField(
                            controller: _passController,
                            obscureText: true,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: "SENHA",
                              labelStyle: const TextStyle(fontSize: 14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              isDense: true, // Achata o campo
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.lock, color: Colors.blue[900], size: 20), // Ícone menor
                            ),
                          ),
                          const SizedBox(height: 25),
                          
                          // BOTÃO ENTRAR REDUZIDO
                          SizedBox(
                            width: double.infinity,
                            height: 45, // Altura reduzida
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _fazerLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[900],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                              child: _isLoading 
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                      SizedBox(width: 10),
                                      Text("CONECTANDO...", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                                    ],
                                  )
                                : const Text("ENTRAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), // Letra menor
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}