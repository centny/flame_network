import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class LinePrinter extends PrettyPrinter {
  LinePrinter() : super(stackTraceBeginIndex: 1);

  @override
  List<String> log(LogEvent event) {
    String timeStr = formatTime(event.time);

    String stackTraceStr = formatStackTrace(event.stackTrace ?? StackTrace.current, 2) ?? "NONE";

    stackTraceStr = stackTraceStr.replaceFirst(RegExp(r"#[0-9]*"), "").trim();

    String levelStr = getLevel(event.level);

    var messageStr = stringifyMessage(event.message);

    var errorStr = " ${event.error?.toString() ?? ""}";

    return ["$timeStr $stackTraceStr $levelStr  $messageStr$errorStr"];
  }

  String getLevel(Level level) {
    switch (level) {
      case Level.trace:
        return "T";
      case Level.debug:
        return "D";
      case Level.warning:
        return "W";
      case Level.info:
        return "I";
      case Level.error:
        return "E";
      default:
        return level.toString();
    }
  }

  String formatTime(DateTime time) {
    return DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(time);
  }
}

class Filter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => event.level.value >= level!.value;
}

var L = Logger(
  filter: Filter(), // Use the default LogFilter (-> only log in debug mode)
  printer: LinePrinter(), // Use the PrettyPrinter to format and print log
  output: ConsoleOutput(), // Use the default LogOutput (-> send everything to console)
);
