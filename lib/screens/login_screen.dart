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

  // =========================================================================
  // SUA LÓGICA DE LOGIN ORIGINAL - MANTIDA PERFEITAMENTE
  // =========================================================================
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
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor removido, pois o fundo agora é a imagem
      body: Stack(
        children: [
          // 1. CAMADA DE IMAGEM DE FUNDO
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_mobile.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // 2. CAMADA DE PELÍCULA ESCURA (Overlay) PARA DAR CONTRASTE
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Color(0xa0000000), BlendMode.srcOver), // Aumentada ligeiramente para melhor leitura
              child: const SizedBox(),
            ),
          ),

          // 3. CAMADA DE CONTEÚDO (Visual atualizado conforme sua imagem modelo)
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // A. ESPAÇO SUPERIOR (Pushando o logo para baixo um pouco)
                  const SizedBox(height: 50),

                  // B. SEÇÃO LOGO - AGORA FORA DO CARD E NO TOPO
                  // Mudando as cores para branco/azul claro para aparecer sobre o fundo
                  Icon(Icons.apartment, size: 80, color: Colors.blue[100]), // Azul bem claro
                  const SizedBox(height: 15),
                  Text(
                    "CONDOLOGIC",
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.blue[100], // Azul bem claro
                      letterSpacing: 2
                    ),
                  ),
                  const Text(
                    "SISTEMA DE FOTOMETRIA", 
                    style: TextStyle(
                      color: Colors.white70, // Branco translúcido
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    )
                  ),

                  // =========================================================================
                  // C. O GRANDE ESPAÇO QUE VOCÊ PEDIU
                  // A imagem de fundo ficará visível aqui, entre o logo e o formulário.
                  // =========================================================================
                  const SizedBox(height: 180), // Ajuste este valor se quiser mais ou menos espaço

                  // D. CARD CONTENDO APENAS O FORMULÁRIO (Fica mais embaixo)
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Título do Formulário mantido, mas com cor original
                          Text(
                            "Acesse sua Conta",
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.blue[900]
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // SEUS CAMPOS DE FORMULÁRIO ORIGINAIS - MANTIDOS
                          TextField(
                            controller: _cpfController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "CPF (Apenas números)",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.person, color: Colors.blue[900]),
                            ),
                          ),
                          const SizedBox(height: 15),
                          
                          TextField(
                            controller: _passController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "SENHA",
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.lock, color: Colors.blue[900]),
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // SEU BOTÃO ORIGINAL - MANTIDO
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _fazerLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[900],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 3,
                              ),
                              child: _isLoading 
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                      SizedBox(width: 15),
                                      Text("CONECTANDO...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    ],
                                  )
                                : const Text("ENTRAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // E. ESPAÇO INFERIOR (Para garantir que a caixa não encoste no final da tela)
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}