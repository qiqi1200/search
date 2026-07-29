class ChinesePoem {
  final String content;
  final String author;
  final String title;

  const ChinesePoem({
    required this.content,
    required this.author,
    required this.title,
  });
}

class PoemDatabase {
  static final List<ChinesePoem> poems = [
    ChinesePoem(content: '人生若只如初见，何事秋风悲画扇', author: '纳兰性德', title: '木兰花·拟古决绝词柬友'),
    ChinesePoem(content: '众里寻他千百度，蓦然回首，那人却在，灯火阑珊处', author: '辛弃疾', title: '青玉案·元夕'),
    ChinesePoem(content: '但愿人长久，千里共婵娟', author: '苏轼', title: '水调歌头'),
    ChinesePoem(content: '床前明月光，疑是地上霜。举头望明月，低头思故乡', author: '李白', title: '静夜思'),
    ChinesePoem(content: '行到水穷处，坐看云起时', author: '王维', title: '终南别业'),
    ChinesePoem(content: '此情可待成追忆，只是当时已惘然', author: '李商隐', title: '锦瑟'),
    ChinesePoem(content: '落霞与孤鹜齐飞，秋水共长天一色', author: '王勃', title: '滕王阁序'),
    ChinesePoem(content: '问君能有几多愁，恰似一江春水向东流', author: '李煜', title: '虞美人'),
    ChinesePoem(content: '采菊东篱下，悠然见南山', author: '陶渊明', title: '饮酒·其五'),
    ChinesePoem(content: '大鹏一日同风起，扶摇直上九万里', author: '李白', title: '上李邕'),
    ChinesePoem(content: '竹杖芒鞋轻胜马，谁怕？一蓑烟雨任平生', author: '苏轼', title: '定风波'),
    ChinesePoem(content: '春风得意马蹄疾，一日看尽长安花', author: '孟郊', title: '登科后'),
    ChinesePoem(content: '海内存知己，天涯若比邻', author: '王勃', title: '送杜少府之任蜀州'),
    ChinesePoem(content: '山重水复疑无路，柳暗花明又一村', author: '陆游', title: '游山西村'),
    ChinesePoem(content: '曾经沧海难为水，除却巫山不是云', author: '元稹', title: '离思五首·其四'),
    ChinesePoem(content: '长风破浪会有时，直挂云帆济沧海', author: '李白', title: '行路难·其一'),
    ChinesePoem(content: '无边落木萧萧下，不尽长江滚滚来', author: '杜甫', title: '登高'),
    ChinesePoem(content: '花间一壶酒，独酌无相亲。举杯邀明月，对影成三人', author: '李白', title: '月下独酌'),
    ChinesePoem(content: '天街小雨润如酥，草色遥看近却无', author: '韩愈', title: '早春呈水部张十八员外'),
    ChinesePoem(content: '世事一场大梦，人生几度秋凉', author: '苏轼', title: '西江月'),
    ChinesePoem(content: '千山鸟飞绝，万径人踪灭。孤舟蓑笠翁，独钓寒江雪', author: '柳宗元', title: '江雪'),
    ChinesePoem(content: '醉后不知天在水，满船清梦压星河', author: '唐珙', title: '题龙阳县青草湖'),
    ChinesePoem(content: '人间四月芳菲尽，山寺桃花始盛开', author: '白居易', title: '大林寺桃花'),
    ChinesePoem(content: '非淡泊无以明志，非宁静无以致远', author: '诸葛亮', title: '诫子书'),
    ChinesePoem(content: '路漫漫其修远兮，吾将上下而求索', author: '屈原', title: '离骚'),
    ChinesePoem(content: '天生我材必有用，千金散尽还复来', author: '李白', title: '将进酒'),
    ChinesePoem(content: '此中有真意，欲辨已忘言', author: '陶渊明', title: '饮酒·其五'),
    ChinesePoem(content: '谁言寸草心，报得三春晖', author: '孟郊', title: '游子吟'),
    ChinesePoem(content: '夕阳无限好，只是近黄昏', author: '李商隐', title: '登乐游原'),
    ChinesePoem(content: '明月几时有，把酒问青天', author: '苏轼', title: '水调歌头'),
    ChinesePoem(content: '独在异乡为异客，每逢佳节倍思亲', author: '王维', title: '九月九日忆山东兄弟'),
    ChinesePoem(content: '欲穷千里目，更上一层楼', author: '王之涣', title: '登鹳雀楼'),
    ChinesePoem(content: '两岸猿声啼不住，轻舟已过万重山', author: '李白', title: '早发白帝城'),
    ChinesePoem(content: '会当凌绝顶，一览众山小', author: '杜甫', title: '望岳'),
    ChinesePoem(content: '停车坐爱枫林晚，霜叶红于二月花', author: '杜牧', title: '山行'),
    ChinesePoem(content: '知否？知否？应是绿肥红瘦', author: '李清照', title: '如梦令'),
    ChinesePoem(content: '两情若是久长时，又岂在朝朝暮暮', author: '秦观', title: '鹊桥仙'),
    ChinesePoem(content: '纸上得来终觉浅，绝知此事要躬行', author: '陆游', title: '冬夜读书示子聿'),
    ChinesePoem(content: '不畏浮云遮望眼，自缘身在最高层', author: '王安石', title: '登飞来峰'),
    ChinesePoem(content: '人间有味是清欢', author: '苏轼', title: '浣溪沙'),
    ChinesePoem(content: '且将新火试新茶，诗酒趁年华', author: '苏轼', title: '望江南·超然台作'),
    ChinesePoem(content: '桃李春风一杯酒，江湖夜雨十年灯', author: '黄庭坚', title: '寄黄几复'),
    ChinesePoem(content: '人生自是有情痴，此恨不关风与月', author: '欧阳修', title: '玉楼春'),
    ChinesePoem(content: '当时明月在，曾照彩云归', author: '晏几道', title: '临江仙'),
    ChinesePoem(content: '小舟从此逝，江海寄余生', author: '苏轼', title: '临江仙·夜饮东坡醒复醉'),
    ChinesePoem(content: '我见青山多妩媚，料青山见我应如是', author: '辛弃疾', title: '贺新郎'),
    ChinesePoem(content: '半亩方塘一鉴开，天光云影共徘徊', author: '朱熹', title: '观书有感'),
    ChinesePoem(content: '莫愁前路无知己，天下谁人不识君', author: '高适', title: '别董大'),
    ChinesePoem(content: '黄沙百战穿金甲，不破楼兰终不还', author: '王昌龄', title: '从军行'),
    ChinesePoem(content: '春蚕到死丝方尽，蜡炬成灰泪始干', author: '李商隐', title: '无题'),
  ];

  static ChinesePoem get randomPoem =>
      poems[DateTime.now().millisecondsSinceEpoch % poems.length];
}
