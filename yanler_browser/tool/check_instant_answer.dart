// 临时校验脚本：验证即时答案服务的计算器/农历/时间/诗词识别。
// 运行：cd yanler_browser && dart run tool/check_instant_answer.dart
import 'package:yanler_browser/features/search/instant_answer.dart';

int _fail = 0;

void _expect(String query, String? expectKind, {String? expectContent}) {
  final a = InstantAnswerService.tryAnswer(query);
  final kind = a?.title ?? 'null';
  final ok = kind == expectKind;
  if (!ok) {
    _fail++;
    print('✗ "$query" => $kind（期望 $expectKind）');
  } else {
    print('✓ "$query" => $kind');
  }
  if (ok && expectContent != null) {
    final c = a!.content;
    if (!c.contains(expectContent)) {
      _fail++;
      print('  ✗ 内容缺「$expectContent」，实际：$c');
    } else {
      print('   内容：${c.replaceAll('\n', ' | ')}');
    }
  }
}

void main() {
  print('== 计算器 ==');
  _expect('12*34+5', '计算', expectContent: '= 413');
  _expect('(1+2)*3', '计算', expectContent: '= 9');
  _expect('2^10', '计算', expectContent: '= 1024');
  _expect('100/4', '计算', expectContent: '= 25');
  _expect('1+2*3-4', '计算', expectContent: '= 3');
  _expect('100/0', 'null'); // 除零 → 跳过
  _expect('python 教程', 'null'); // 普通词 → Bing
  _expect('12*34+5 是什么意思', 'null'); // 含文字 → Bing

  print('\n== 时间 ==');
  _expect('现在几点', '时间');
  _expect('今天日期', '时间');
  _expect('现在时间', '时间');

  print('\n== 农历 ==');
  _expect('农历', '农历');
  _expect('今天农历几号', '农历');

  print('\n== 农历算法（已知日期校验）==');
  _checkLunar(2024, 2, 10, '2024年正月初一');
  _checkLunar(2024, 2, 24, '2024年正月十五');
  _checkLunar(2025, 1, 29, '2025年正月初一');
  _checkLunar(2026, 2, 17, '2026年正月初一');

  print('\n== 诗词 ==');
  _expect('诗词 月', '诗词');
  _expect('来一首诗', '诗词');
  _expect('诗词 明月', '诗词');

  print('\n${_fail == 0 ? "全部通过 ✅" : "有 $_fail 项失败 ❌"}');
}

void _checkLunar(int y, int m, int d, String expected) {
  final got = InstantAnswerService.solarToLunar(DateTime(y, m, d));
  final ok = got.contains(expected.replaceFirst(RegExp(r'^\d+年'), ''));
  // 年份单独校验（输出含公元年，断言后缀即可）
  if (!ok) {
    _fail++;
    print('✗ $y-$m-$d 期望含「${expected.replaceFirst(RegExp(r'^\d+年'), '')}」，实际：$got');
  } else {
    print('✓ $y-$m-$d => $got');
  }
}
