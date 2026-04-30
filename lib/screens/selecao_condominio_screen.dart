// ==========================================>>> selecao_condominio_screen.dart (MOBILE)
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class SelecaoCondominioScreen extends StatelessWidget {
  final Map user;
  final List<dynamic> condominios;

  const SelecaoCondominioScreen({super.key, required this.user, required this.condominios});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("Selecione o Condomínio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: condominios.isEmpty
          ? const Center(child: Text("Nenhum condomínio vinculado a este usuário.", style: TextStyle(fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: condominios.length,
              itemBuilder: (context, index) {
                final t = condominios[index];
                
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue[100], shape: BoxShape.circle),
                      child: Icon(Icons.apartment, color: Colors.blue[900], size: 30),
                    ),
                    title: Text(t['nome'] ?? 'Desconhecido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[900])),
                    subtitle: const Text("Toque para acessar os blocos", style: TextStyle(color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    onTap: () async {
                      // 1. Atualizamos o tenant no objeto
                      user['tenant_id'] = t['id'];
                      user['tenant_nome'] = t['nome'];

                      // 2. Salva a Sessão Definitiva (Assim o cara não precisa logar de novo)
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('user_session', jsonEncode(user));

                      // 3. Pula pro Dashboard
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => DashboardScreen(user: user)),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}