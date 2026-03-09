class QuestionItem {
  const QuestionItem({required this.title, required this.info});

  final String title;
  final String info;
}

class QuestionAnswer {
  const QuestionAnswer({this.value, this.changed = false});

  final double? value;
  final bool changed;
}
