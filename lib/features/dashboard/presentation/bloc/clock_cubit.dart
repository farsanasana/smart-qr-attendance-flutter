import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Emits live current [DateTime] every second for dashboard clock display.
class ClockCubit extends Cubit<DateTime> {
  ClockCubit() : super(DateTime.now()) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(DateTime.now());
    });
  }

  late final Timer _timer;

  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}

/// Manages bottom navigation tab index for the Employee Shell without setState.
class EmployeeNavCubit extends Cubit<int> {
  EmployeeNavCubit() : super(0);

  void selectTab(int index) => emit(index);
}

