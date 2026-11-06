import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FinanceChanges {
  final _listeners = <VoidCallback>[];

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notify() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }
}

class ReloadOnChange extends StatefulWidget {
  const new({
    required this.changes,
    required this.onChange,
    required this.child,
    super.key,
  });

  final FinanceChanges changes;
  final void Function(BuildContext context) onChange;
  final Widget child;

  @override
  State<ReloadOnChange> createState() => _ReloadOnChangeState();
}

class _ReloadOnChangeState extends State<ReloadOnChange> {
  @override
  void initState() {
    super.initState();
    widget.changes.addListener(_changed);
  }

  @override
  void dispose() {
    widget.changes.removeListener(_changed);
    super.dispose();
  }

  void _changed() => widget.onChange(context);

  @override
  Widget build(BuildContext context) => widget.child;
}
