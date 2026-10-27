// Language selection dropdown used by Settings.
/*
 * Modified from https://github.com/babstrap/babstrap_settings_screen (babstrap_settings_screen)
 * Licensed under the MIT license
 * Please support the original developer by starring the repository
*/

import 'package:flutter/material.dart';

class SettingsItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final ValueChanged<dynamic>? onChange;
  final Map<String, dynamic>? values;
  final String selected;
  final Color? backgroundColor;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.backgroundColor,
    required this.selected,
    required this.values,
    this.onChange,
  });

  @override
  State<SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        color: widget.backgroundColor,
        child: ListTile(
          leading: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(widget.icon),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: DropdownButton<String>(
            alignment: Alignment.centerRight,
            underline: Container(),
            value: widget.values!.keys.firstWhere(
              (key) => widget.values![key] == widget.selected,
              orElse: () => widget.selected,
            ),
            items: widget.values!.keys.map((String key) {
              return DropdownMenuItem<String>(
                value: key,
                child: Text(widget.values![key]),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                widget.onChange!(newValue);
              });
            },
          ),
        ),
      ),
    );
  }
}
