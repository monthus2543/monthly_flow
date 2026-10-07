import 'package:flutter/material.dart';

const currencySymbols = <String, String>{
  'THB': '฿', 'USD': '\$', 'EUR': '€', 'GBP': '£',
  'JPY': '¥', 'CNY': '¥', 'SGD': '\$',
};

class AppCurrency extends ThemeExtension<AppCurrency> {
  const AppCurrency(this.code);
  final String code;
  String get symbol => currencySymbols[code] ?? currencySymbols['THB']!;
  @override
  AppCurrency copyWith({String? code}) => AppCurrency(code ?? this.code);
  @override
  AppCurrency lerp(covariant AppCurrency? other, double t) => other ?? this;
}
