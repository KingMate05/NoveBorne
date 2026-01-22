import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ScanReader extends HookWidget {
  final void Function(String value, [bool force]) onScan;
  final String scanIdentifier;
  final Widget? widget;
  final bool? hideCloseIcon;
  final ValueNotifier<int>? activeScan;
  final Function(int value)? changeActive;
  final int? index;

  const ScanReader(
      {super.key,
      required this.onScan,
      required this.scanIdentifier,
      this.widget,
      this.hideCloseIcon,
      this.activeScan,
      this.index,
      this.changeActive});

  @override
  Widget build(BuildContext context) {
    var controller = useState<TextEditingController>(TextEditingController());
    var keyboardShowed = useState<bool>(false);
    var visible = useState<bool>(true);
    var edit = useState<bool>(widget == null);

    closeEdit() {
      // do not remove
      edit.value = false;
    }

    openKeyboard() {
      keyboardShowed.value = true;
      SystemChannels.textInput.invokeMethod("TextInput.show");
    }

    closeKeyboard() {
      keyboardShowed.value = false;
      SystemChannels.textInput.invokeMethod("TextInput.hide");
      controller.value.clear();
    }

    useEffect(() {
      thisHandle(KeyEvent keyEvent) {
        if (keyboardShowed.value == false ||
            (activeScan != null && activeScan!.value != index)) {
          return false;
        }
        if (keyEvent.logicalKey == LogicalKeyboardKey.backspace &&
            controller.value.text.isNotEmpty) {
          controller.value.text = controller.value.text
              .substring(0, controller.value.text.length - 1);
        } else if (keyEvent.logicalKey == LogicalKeyboardKey.enter) {
          onScan(controller.value.text);
          closeKeyboard();
        } else {
          var newChar = keyEvent.character.toString();
          if (newChar.length == 1) {
            controller.value.text += newChar;
          }
        }
        return true;
      }

      HardwareKeyboard.instance.addHandler(thisHandle);
      return () {
        HardwareKeyboard.instance.removeHandler(thisHandle);
      };
    }, []);

    return VisibilityDetector(
      onVisibilityChanged: (VisibilityInfo info) {
        if (context.mounted) {
          visible.value = info.visibleFraction > 0;
        }
      },
      key: Key(scanIdentifier),
      child: BarcodeKeyboardListener(
        bufferDuration: const Duration(milliseconds: 200),
        onBarcodeScanned: (newBarcode) {
          if (!visible.value ||
              (activeScan != null && activeScan!.value != index)) return;
          if (newBarcode != '') {
            onScan(newBarcode);
          }
        },
        useKeyDownEvent: Platform.isWindows,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (activeScan != null &&
                changeActive != null &&
                index != null) ...[
              IconButton(
                icon: Icon(
                  Icons.circle,
                  size: 10,
                  color: activeScan!.value == index ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  changeActive!(index!);
                },
              ),
            ],
            if (edit.value) ...[
              Expanded(
                child: TextField(
                  autofocus: false,
                  readOnly: true,
                  keyboardType: TextInputType.text,
                  controller: controller.value,
                  decoration: InputDecoration(
                    suffixIcon: hideCloseIcon == true
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              closeKeyboard();
                            },
                          ),
                    hintText: 'Recherche...',
                  ),
                  onTap: () {
                    openKeyboard();
                  },
                ),
              ),
            ] else ...[
              widget!
            ],
            if (widget != null) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  edit.value = !edit.value;
                  if(edit.value) {
                    openKeyboard();
                    if (index != null && edit.value) {
                      activeScan!.value = index!;
                    }
                  } else {
                    closeKeyboard();
                  }
                },
              )
            ]
          ],
        ),
      ),
    );
  }
}
