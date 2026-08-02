import 'dart:math';
import '../../core/utils/poem_database.dart';

/// 本地即时答案类型
enum InstantAnswerKind {
  calculator, // 计算器
  time, // 时间 / 日期 / 星期
  lunar, // 农历
  poem, // 诗词
}

/// 一条本地即时答案（零网络、零 AI、免 VPN）。
///
/// [content] 为多行展示内容；[copyText] 为点「复制」写入剪贴板的内容。
class InstantAnswer {
  final InstantAnswerKind kind;
  final String title;
  final String content;
  final String copyText;

  const InstantAnswer({
    required this.kind,
    required this.title,
    required this.content,
    required this.copyText,
  });
}

/// Yanler 内置「即时答案」服务。
///
/// 设计目标（替代失败的聚合搜索）：
/// - 命中「计算 / 时间 / 农历 / 诗词」等类型 → 本地直接出答案，零网络零 AI；
/// - 其余一律走 Bing 兜底（见 browser_screen，通用词直接打开 cn.bing.com）。
/// 全部可离线、无需 VPN，且没有任何 scraper 反爬依赖，天然不会坏。
class InstantAnswerService {
  InstantAnswerService._();

  /// 对查询做意图识别，命中本地答案返回结果，否则返回 null（走 Bing）。
  static InstantAnswer? tryAnswer(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;

    final calculator = _tryCalculator(q);
    if (calculator != null) return calculator;
    final time = _tryTime(q);
    if (time != null) return time;
    final lunar = _tryLunar(q);
    if (lunar != null) return lunar;
    final poem = _tryPoem(q);
    if (poem != null) return poem;

    return null;
  }

  // ==================== 计算器 ====================

  static InstantAnswer? _tryCalculator(String q) {
    // 只允许数字与运算符；且必须至少含一个运算符（避免把普通搜索当计算）
    if (q.length > 60) return null;
    final s = q.replaceAll(' ', '').replaceAll('，', ',');
    if (s.isEmpty) return null;
    if (!RegExp(r'^[0-9+\-*/%^().,]+$').hasMatch(s)) return null;
    if (!s.contains(RegExp(r'[+\-*/%^]'))) return null;

    // 括号配对
    var depth = 0;
    for (final c in s.split('')) {
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth < 0) return null;
    }
    if (depth != 0) return null;

    final result = _evaluate(s);
    if (result == null) return null;
    return InstantAnswer(
      kind: InstantAnswerKind.calculator,
      title: '计算',
      content: '= ${_formatNum(result)}',
      copyText: _formatNum(result),
    );
  }

  /// 安全表达式求值（递归下降）。仅支持 + - * / % ^ ( ) 与小数。
  /// 任何解析失败 / 除零 / 溢出都返回 null，绝不抛异常。
  static double? _evaluate(String s) {
    final tokens = _tokenize(s);
    if (tokens.isEmpty) return null;
    final parser = _ExprParser(tokens);
    final result = parser.parseExpr();
    if (result == null || result.isNaN || result.isInfinite) return null;
    if (parser.index != tokens.length) return null; // 有残留 token → 非法
    return result;
  }

  static List<String> _tokenize(String s) {
    final tokens = <String>[];
    final buf = StringBuffer();
    for (final c in s.split('')) {
      if ('0123456789.'.contains(c)) {
        buf.write(c);
      } else {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
        tokens.add(c);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }

  /// 数字展示：整数去小数点；长小数截到最多 8 位并去尾零。
  static String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    var s = v.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  // ==================== 时间 / 日期 / 星期 ====================

  static InstantAnswer? _tryTime(String q) {
    // 仅当查询是「问时间/日期」类短句时命中，避免误伤普通搜索
    if (q.length > 12) return null;
    final isTimeQuestion = RegExp(r'(几点|几点了|几点钟|现在时间|现在几号|'
            r'今天几号|今天日期|今天星期|星期几|日期|时间)')
        .hasMatch(q);
    if (!isTimeQuestion) return null;

    final now = DateTime.now();
    const week = ['一', '二', '三', '四', '五', '六', '日'];
    final content =
        '现在时间：${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}\n'
        '今天日期：${now.year}年${now.month}月${now.day}日\n'
        '星期${week[now.weekday - 1]}';
    return InstantAnswer(
      kind: InstantAnswerKind.time,
      title: '时间',
      content: content,
      copyText: content,
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  // ==================== 农历 ====================

  static InstantAnswer? _tryLunar(String q) {
    if (!q.contains('农历')) return null;
    if (q.length > 12) return null;

    final today = DateTime.now();
    final lunar = solarToLunar(today);
    final content = '今天 ${today.year}-${_pad(today.month)}-${_pad(today.day)}\n'
        '农历 $lunar';
    return InstantAnswer(
      kind: InstantAnswerKind.lunar,
      title: '农历',
      content: content,
      copyText: content,
    );
  }

  /// 农历 1900–2100 年数据表（标准算法）。每项低 4 位 = 闰月月份（0=无闰），
  /// 高 16 位逐位表示 1–12 月是否为大月（30 天）。
  static const List<int> _lunarInfo = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0,
    0x09ad0, 0x055d2, // 1900-1909
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2,
    0x095b0, 0x14977, // 1910-1919
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570,
    0x052f2, 0x04970, // 1920-1929
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0,
    0x1c8d7, 0x0c950, // 1930-1939
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2,
    0x0a950, 0x0b557, // 1940-1949
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8,
    0x0e950, 0x06aa0, // 1950-1959
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950,
    0x05b57, 0x056a0, // 1960-1969
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540,
    0x0b6a0, 0x195a6, // 1970-1979
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46,
    0x0ab60, 0x09570, // 1980-1989
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60,
    0x096d5, 0x092e0, // 1990-1999
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0,
    0x092d0, 0x0cab5, // 2000-2009
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176,
    0x052b0, 0x0a930, // 2010-2019
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260,
    0x0ea65, 0x0d530, // 2020-2029
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250,
    0x0d520, 0x0dd45, // 2030-2039
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255,
    0x06d20, 0x0ada0, // 2040-2049
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20,
    0x1a6c4, 0x0aae0, // 2050-2059
    0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0,
    0x0a6d0, 0x055d4, // 2060-2069
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4,
    0x0a5b0, 0x052b0, // 2070-2079
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570,
    0x054e4, 0x0d160, // 2080-2089
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0,
    0x0d150, 0x0f252, // 2090-2099
    0x0d520, // 2100
  ];

  static const List<String> _cnMonths = [
    '正', '二', '三', '四', '五', '六',
    '七', '八', '九', '十', '冬', '腊',
  ];

  static final List<String> _cnDays = _buildCnDays();

  static List<String> _buildCnDays() {
    final days = <String>[];
    const tens = ['', '十', '廿'];
    for (var d = 1; d <= 30; d++) {
      if (d <= 10) {
        days.add('初${'一二三四五六七八九十'[d - 1]}');
      } else if (d == 20) {
        days.add('二十');
      } else if (d == 30) {
        days.add('三十');
      } else {
        days.add('${tens[d ~/ 10]}${'一二三四五六七八九'[d % 10 - 1]}');
      }
    }
    return days;
  }

  /// 公历 → 农历（1900–2100）。标准算法（lunar.js 移植）。
  /// 公开以便单元测试与未来复用（如首页农历展示）。
  static String solarToLunar(DateTime date) {
    final base = DateTime(1900, 1, 31); // 农历 1900 正月初一
    var offset = date.difference(base).inDays;

    var yearIdx = 0;
    var temp = 0;
    // 先定位年份
    while (yearIdx < _lunarInfo.length && offset > 0) {
      temp = _lunarYearDays(_lunarInfo[yearIdx]);
      offset -= temp;
      yearIdx++;
    }
    if (offset < 0) {
      offset += temp;
      yearIdx--;
    }
    if (yearIdx < 0 || yearIdx >= _lunarInfo.length) return '超出支持范围（1900–2100）';
    final lunarYear = 1900 + yearIdx;
    final info = _lunarInfo[yearIdx];

    final leapMonth = info & 0xf; // 闰月月份，0=无闰
    var isLeap = false;
    var m = 1;
    for (m = 1; m <= 12 && offset > 0; m++) {
      if (leapMonth > 0 && m == leapMonth + 1 && !isLeap) {
        // 该月是闰月：先减闰月天数，循环变量回退使下一次迭代继续处理该月
        --m;
        isLeap = true;
        temp = _leapDays(info);
      } else {
        temp = (info & (0x10000 >> m)) != 0 ? 30 : 29;
      }
      if (isLeap && m == leapMonth + 1) isLeap = false;
      offset -= temp;
    }
    if (offset == 0 && leapMonth > 0 && m == leapMonth + 1) {
      // 恰好落在闰月边界
      if (isLeap) {
        isLeap = false;
      } else {
        isLeap = true;
        --m;
      }
    }
    if (offset < 0) {
      offset += temp;
      --m;
    }
    if (m < 1 || m > 12) return '农历计算异常';
    final day = offset + 1;
    if (day < 1 || day > 30) return '农历计算异常';

    final monthStr = _cnMonthName(m, isLeap);
    return '$lunarYear年$monthStr${_cnDays[day - 1]}';
  }

  /// 农历月份中文名：正月 / 二月…十月 / 冬月 / 腊月；闰月加「闰」前缀。
  static String _cnMonthName(int m, bool isLeap) {
    final base = switch (m) {
      1 => '正月',
      11 => '冬月',
      12 => '腊月',
      _ => '${_cnMonths[m - 1]}月',
    };
    return isLeap ? '闰$base' : base;
  }

  static int _lunarYearDays(int info) {
    var sum = 348; // 12 个月 * 29 天基准
    for (var m = 0x8000; m > 0x8; m >>= 1) {
      sum += (info & m) != 0 ? 1 : 0;
    }
    return sum + _leapDays(info);
  }

  static int _leapDays(int info) {
    // 闰月 30/29 标志位是最高位 0x10000（与闰月序号无关）
    final lm = info & 0xf;
    return lm == 0 ? 0 : ((info & 0x10000) != 0 ? 30 : 29);
  }

  // ==================== 诗词 ====================

  static InstantAnswer? _tryPoem(String q) {
    final trimmed = q.trim();
    final trigger = RegExp(r'^(诗词|诗句|古诗|诗|找一首诗|来一首诗)');
    if (!trigger.hasMatch(trimmed)) return null;

    final kw = trimmed.replaceFirst(trigger, '').trim();
    final poems = PoemDatabase.search(kw);
    if (poems.isEmpty) {
      return InstantAnswer(
        kind: InstantAnswerKind.poem,
        title: '诗词',
        content: '未找到含「$kw」的诗句\n试试：诗词 月 / 诗词 明月 / 来一首诗',
        copyText: '',
      );
    }
    final sb = StringBuffer();
    for (final p in poems.take(5)) {
      sb.writeln(p.content);
      sb.writeln('——《${p.title}》 ${p.author}');
      sb.writeln();
    }
    final content = sb.toString().trim();
    return InstantAnswer(
      kind: InstantAnswerKind.poem,
      title: '诗词',
      content: content,
      copyText: content,
    );
  }
}

/// 递归下降表达式解析器（类方法间可互相调用，规避 Dart 局部函数前向引用限制）。
///
/// 语法：expr = term {(+|-) term}；term = unary {(*|/|%) unary}；
/// unary = [-] unary | power；power = atom [^ power]；atom = number | ( expr )。
class _ExprParser {
  final List<String> tokens;
  int index = 0;

  _ExprParser(this.tokens);

  double? parseExpr() {
    var left = parseTerm();
    while (index < tokens.length &&
        (tokens[index] == '+' || tokens[index] == '-')) {
      final op = tokens[index++];
      final right = parseTerm();
      if (left == null || right == null) return null;
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double? parseTerm() {
    var left = parseUnary();
    while (index < tokens.length &&
        (tokens[index] == '*' || tokens[index] == '/' || tokens[index] == '%')) {
      final op = tokens[index++];
      final right = parseUnary();
      if (left == null || right == null) return null;
      if (op == '*') {
        left = left * right;
      } else if (op == '/') {
        if (right == 0) return null;
        left = left / right;
      } else {
        if (right == 0) return null;
        left = left % right;
      }
    }
    return left;
  }

  double? parseUnary() {
    if (index < tokens.length && tokens[index] == '-') {
      index++;
      final v = parseUnary();
      return v == null ? null : -v;
    }
    if (index < tokens.length && tokens[index] == '+') {
      index++;
      return parseUnary();
    }
    return parsePower();
  }

  double? parsePower() {
    final base = parseAtom();
    if (index < tokens.length && tokens[index] == '^') {
      index++;
      final exp = parsePower(); // 右结合：2^3^2 = 2^(3^2)
      if (base == null || exp == null) return null;
      return pow(base, exp).toDouble();
    }
    return base;
  }

  double? parseAtom() {
    if (index < tokens.length && tokens[index] == '(') {
      index++;
      final v = parseExpr();
      if (index < tokens.length && tokens[index] == ')') {
        index++;
        return v;
      }
      return null;
    }
    if (index < tokens.length) {
      final v = double.tryParse(tokens[index]);
      if (v != null) {
        index++;
        return v;
      }
    }
    return null;
  }
}
