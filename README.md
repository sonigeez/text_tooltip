
# Text Tooltip

A Flutter package for easily adding tooltips to text elements in your Flutter applications. With `text_tooltip`, you can enhance the user experience by providing informative messages in a visually appealing way. This package allows for custom tooltip messages, styles, and positions, making it a versatile choice for any Flutter project.

## Features

- **Customizable Tooltip Messages:** Define your own tooltip message to display.
- **Flexible Positioning:** Choose from predefined positions to show your tooltip exactly where you want.
- **Style Customization:** Customize text styles to match your app's design.
- **Disability Option:** Optionally disable tooltips.

## Getting Started

To get started with `text_tooltip`, you will first need to add it to your Flutter project's dependencies.

### Installation

Add `text_tooltip` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  text_tooltip:
    git:
      url: https://github.com/sonigeez/text_tooltip.git
      ref: main
```

Then, run the following command to install the package:

```sh
flutter pub get
```

### Usage

To use `text_tooltip` in your Flutter app, follow these steps:

1. Import the package:

```dart
import 'package:text_tooltip/text_tooltip.dart';
```

2. Wrap any widget with `TextToolTip` to add a tooltip:

```dart
TextToolTip(
  message: "Hello World",
  tooltipPosition: TooltipPosition.up,
  textStyle: TextStyle(
    fontSize: 16,
    color: Colors.black,
  ),
  child: // Your widget here,
)
```

### Example
you can see example in the example folder


## Contributing

Contributions to `text_tooltip` are welcome. Please feel free to open an issue or submit a pull request.
