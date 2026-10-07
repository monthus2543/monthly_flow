import 'package:flutter/material.dart';
import '../color/color.dart';
import '../l10n/app_localizations.dart';

Future<Color?> showCategoryColorPicker(BuildContext context, Color initial) =>
    showDialog<Color>(
      context: context,
      builder: (_) => _ColorPicker(initial: initial),
    );

class _ColorPicker extends StatefulWidget {
  const _ColorPicker({required this.initial});
  final Color initial;
  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  final form = GlobalKey<FormState>();
  late final TextEditingController hex;
  late Color selected;
  static const palette = [
    AppColors.categoryExpense,
    AppColors.categoryIncome,
    AppColors.blue,
    AppColors.purple,
    AppColors.orange,
    AppColors.rose,
    AppColors.tealDark,
    AppColors.errorDark,
    AppColors.blueDark,
    AppColors.purpleDark,
  ];
  String code(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  Color? parse(String value) {
    final text = value.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)) return null;
    return Color(0xff000000 | int.parse(text, radix: 16));
  }

  @override
  void initState() {
    super.initState();
    selected = widget.initial;
    hex = TextEditingController(text: code(selected));
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.t('category_text_color')),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in palette)
                  Semantics(
                    selected: selected == color,
                    button: true,
                    label: code(color),
                    child: InkWell(
                      key: ValueKey('category-color-${code(color)}'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() {
                        selected = color;
                        hex.text = code(color);
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: selected == color
                            ? Icon(
                                Icons.check,
                                color: color.computeLuminance() > .4
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: hex,
              decoration: InputDecoration(
                labelText: context.l10n.t('category_color_hex'),
                prefixIcon: Icon(Icons.circle, color: selected),
              ),
              onChanged: (value) {
                final color = parse(value);
                if (color != null) setState(() => selected = color);
              },
              validator: (value) => parse(value ?? '') == null
                  ? context.l10n.t('category_color_invalid')
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.t('category'),
              style: TextStyle(color: selected, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.t('cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate())
            Navigator.pop(context, parse(hex.text));
        },
        child: Text(context.l10n.t('save_category')),
      ),
    ],
  );
}
