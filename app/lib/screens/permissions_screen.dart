import 'package:flutter/material.dart';

import '../gen/copy.dart';
import '../services/permissions_service.dart';
import '../theme/theme_spec.dart';

/// Shown once, right after sign-in (see PermissionsService). The button runs
/// every system permission prompt in a row; when they are done the router
/// moves on by itself.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    await PermissionsService.instance.requestAll();
    if (mounted) setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                copy.permissions.title,
                style: TextStyle(
                  fontSize: context.tokens.size.headline,
                  fontWeight: context.tokens.weight.heavy,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _requesting ? null : _request,
                  child: Text(
                    copy.permissions.button,
                    style: TextStyle(fontWeight: context.tokens.weight.heavy),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
