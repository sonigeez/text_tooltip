import 'package:flutter/material.dart';
import 'package:text_tooltip/text_tooltip.dart';

void main() {
  runApp(const TextTooltipExample());
}

class TextTooltipExample extends StatelessWidget {
  const TextTooltipExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Tooltip Example',
      theme: ThemeData.dark(),
      home: const TextTooltipExamplePage(),
    );
  }
}

class TextTooltipExamplePage extends StatefulWidget {
  const TextTooltipExamplePage({super.key});

  @override
  State<TextTooltipExamplePage> createState() => _TextTooltipExamplePageState();
}

class _TextTooltipExamplePageState extends State<TextTooltipExamplePage> {
  bool _showTooltip = false;
  bool _showDisableTooltip = false;
  final String _tooltipMessage = 'Hello World';
  //global key
  final GlobalKey _tooltipKey = GlobalKey();
  TooltipPosition _tooltipPosition = TooltipPosition.up;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Tooltip Example'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextToolTip(
              key: _tooltipKey,
              tooltipPosition: _tooltipPosition,
              message: _tooltipMessage,
              textStyle: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
              showDisable: _showDisableTooltip,
              child: TextButton(
                onPressed: () {
                  final dynamic tooltip = _tooltipKey.currentState;
                  tooltip.ensureTooltipVisible();
                },
                child: const Text('Show Tooltip'),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Tooltip Position"),
            DropdownButton<TooltipPosition>(
              value: _tooltipPosition,
              icon: const Icon(Icons.arrow_downward),
              onChanged: (TooltipPosition? newValue) {
                setState(() {
                  if (newValue != null) {
                    _tooltipPosition = newValue;
                  }
                });
              },
              items: TooltipPosition.values
                  .map<DropdownMenuItem<TooltipPosition>>(
                      (TooltipPosition value) {
                return DropdownMenuItem<TooltipPosition>(
                  value: value,
                  child: Text(value.toString().split('.').last),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text("Show Disable Tooltip"),
            Switch(
              value: _showDisableTooltip,
              onChanged: (bool? newValue) {
                setState(() {
                  if (newValue != null) {
                    _showDisableTooltip = newValue;
                  }
                });
              },
            )
          ],
        ),
      ),
    );
  }
}
