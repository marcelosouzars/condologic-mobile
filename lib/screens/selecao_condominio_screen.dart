// ==========================================>>> selecao_condominio_screen.dart

import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class SelecaoCondominioScreen extends StatelessWidget {
  final Map user;
  SelecaoCondominioScreen({required this.user});

  final List<Map> condominios = [
    {'id': 1, 'nome': 'Condomínio Piloto'},
    {'id': 2, 'nome': 'Residencial ABEOC'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Selecione o Condomínio")),
      body: ListView.builder(
        itemCount: condominios.length,
        itemBuilder: (context, index) {
          final t = condominios[index];
          return ListTile(
            title: Text(t['nome']),
            onTap: () {
              // Atualizamos o tenant_id no objeto user antes de passar adiante
              user['tenant_id'] = t['id'];
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DashboardScreen(user: user)),
              );
            },
          );
        },
      ),
    );
  }
}