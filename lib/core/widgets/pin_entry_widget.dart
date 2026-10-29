import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class PinEntryWidget extends StatefulWidget {
  const PinEntryWidget({super.key});

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  String _pin = '';
  int _attempts = 0;
  bool _isLockedOut = false;

  void _onKeypadTap(String value) {
    if (_isLockedOut || _pin.length >= 4) return;
    setState(() {
      _pin += value;
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _verifyPin() {
    // Phase 1 Mock Verification
    if (_pin == '1234') {
      context.pop(); 
      context.go('/family');
    } else {
      setState(() {
        _attempts++;
        _pin = '';
        if (_attempts >= 5) {
          _isLockedOut = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isLockedOut ? 'Too many attempts. Locked.' : 'Enter Family PIN',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isLockedOut ? AppTheme.red : null,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _pin.length ? AppTheme.primaryTeal : AppTheme.background,
                  border: Border.all(color: AppTheme.primaryTeal, width: 2),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          if (!_isLockedOut) _buildKeypad(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index == 9) return const SizedBox.shrink();
        if (index == 11) {
          return IconButton(
            onPressed: _onBackspace,
            icon: const Icon(Icons.backspace, size: 32),
            color: AppTheme.primaryTeal,
          );
        }
        final number = index == 10 ? '0' : '${index + 1}';
        return InkWell(
          onTap: () => _onKeypadTap(number),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}