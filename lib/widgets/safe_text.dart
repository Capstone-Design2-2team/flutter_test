import 'package:flutter/material.dart';

class SafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const SafeText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style?.copyWith(
            overflow: overflow ?? TextOverflow.ellipsis,
          ) ??
          const TextStyle(overflow: TextOverflow.ellipsis),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}

class SafeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final InputDecoration? decoration;
  final TextStyle? style;

  const SafeTextField({
    Key? key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.enabled = true,
    this.onChanged,
    this.onTap,
    this.decoration,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      onTap: onTap,
      style: style?.copyWith(
            overflow: TextOverflow.ellipsis,
          ) ??
          const TextStyle(overflow: TextOverflow.ellipsis),
      decoration: decoration?.copyWith(
            hintStyle: decoration?.hintStyle?.copyWith(
                  overflow: TextOverflow.ellipsis,
                ) ??
                const TextStyle(
                  overflow: TextOverflow.ellipsis,
                  color: Colors.grey,
                ),
          ),
    );
  }
}

class SafeButtonText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SafeButtonText(
    this.text, {
    Key? key,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style?.copyWith(
            overflow: TextOverflow.ellipsis,
          ) ??
          const TextStyle(overflow: TextOverflow.ellipsis),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
