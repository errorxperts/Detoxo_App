import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds the FAQ search query. The view derives the filtered/grouped list from
/// this via `filterFaqs` (in `data/`), which keeps the filtering logic pure and
/// unit-testable independent of the cubit.
class FaqCubit extends Cubit<String> {
  FaqCubit() : super('');

  void search(String query) => emit(query);
}
