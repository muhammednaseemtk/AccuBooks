import 'package:flutter/material.dart';
import '../utils/date_utils.dart';
import 'app_text_field.dart';

class AppDatePickerField extends StatefulWidget {
  final String? label;
  final String? hint;
  final DateTime? value;
  final DateTime? initialPickerDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool isRequired;
  final bool enabled;
  final Widget? prefixIcon;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const AppDatePickerField({
    super.key,
    this.label,
    this.hint,
    required this.value,
    this.initialPickerDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
    this.isRequired = false,
    this.enabled = true,
    this.prefixIcon,
    this.focusNode,
    this.validator,
  });

  @override
  State<AppDatePickerField> createState() => _AppDatePickerFieldState();
}

class _AppDatePickerFieldState extends State<AppDatePickerField> {
  late final TextEditingController _controller;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? AppDateUtils.format(widget.value) : '',
    );
  }

  @override
  void didUpdateWidget(AppDatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newText = widget.value != null ? AppDateUtils.format(widget.value) : '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePick(BuildContext context) async {
    if (!widget.enabled || _isPicking) return;
    _isPicking = true;
    try {
      final picked = await AppDateUtils.pickDate(
        context: context,
        initialDate: widget.value ?? widget.initialPickerDate ?? DateTime.now(),
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
      );

      if (picked != null && mounted) {
        widget.onDateSelected(picked);
      }
    } finally {
      if (mounted) {
        _isPicking = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: widget.hint ?? 'DD-MM-YYYY',
      controller: _controller,
      readOnly: true,
      enabled: widget.enabled,
      isRequired: widget.isRequired,
      focusNode: widget.focusNode,
      prefixIcon: widget.prefixIcon,
      validator: widget.validator,
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
        tooltip: 'Select date',
        onPressed: widget.enabled ? () => _handlePick(context) : null,
      ),
      onTap: widget.enabled ? () => _handlePick(context) : null,
    );
  }
}
