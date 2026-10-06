import 'package:flutter/material.dart';
import '../screens/account_screen.dart';

/// Account controls live inline in settings; syncing is in the data section.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});
  @override
  Widget build(BuildContext context) =>
      const AccountScreen(embedded: true, showSync: false);
}
