import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../screens/cart_screen.dart';

class CartButton extends StatelessWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => IconButton(
          tooltip: 'Panier',
          icon: Badge(
            isLabelVisible: app.cartCount > 0,
            label: Text('${app.cartCount}'),
            backgroundColor: C.green,
            textColor: Colors.black,
            child: Icon(Icons.shopping_cart_outlined),
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen())),
        ),
      );
}
