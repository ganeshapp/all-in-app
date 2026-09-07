// GENERATED reference outputs computed by running the desktop TypeScript
// (src/game/handHistory.ts) under Node 23 with TZ=UTC. Do not hand-edit.
// ignore_for_file: lines_longer_than_80_chars

class RefFrame {
  const RefFrame(
    this.text,
    this.street,
    this.board,
    this.pot,
    this.folded,
    this.revealAll,
  );
  final String text;
  final String street;
  final List<String> board;
  final num pot;
  final List<int> folded;
  final bool revealAll;
}

const String kRefHandText =
    'PokerStars Hand #178187040000001: Hold\'em No Limit (10/20) - 2026/06/19 12:00:00 ET\nTable \'All-In Dojo\' 6-max Seat #1 is the button\nSeat 1: You (2000 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (2000 in chips)\nSeat 4: Dwan (2000 in chips)\nSeat 5: Selbst (2000 in chips)\nSeat 6: Galfond (2000 in chips)\nIvey: posts small blind 10\nPolk: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [As Ks]\nDwan: raises 40 to 60\nYou: calls 60\n*** FLOP *** [Ah Kd 7c]\nDwan: bets 80\nYou: calls 80\n*** TURN *** [Ah Kd 7c] [2s]\nDwan: checks\nYou: checks\n*** RIVER *** [Ah Kd 7c 2s] [9h]\nDwan: checks\nYou: bets 120\nDwan: calls 120\n*** SHOW DOWN ***\nYou: shows [As Ks] (two pair, Aces and Kings)\nDwan: shows [Qh Qd] (a pair of Queens)\nYou collected 520 from pot\n*** SUMMARY ***\nTotal pot 520 | Rake 0\nBoard [Ah Kd 7c 2s 9h]\nSeat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings\nSeat 2: Ivey (small blind) folded before Flop\nSeat 3: Polk (big blind) folded before Flop\nSeat 4: Dwan showed [Qh Qd] and lost with a pair of Queens\nSeat 5: Selbst folded before Flop\nSeat 6: Galfond folded before Flop';

const String kRefHandJson =
    '{"id":1,"startedAt":1781870400000,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":2,"seats":[{"seat":0,"name":"You","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"Ivey","stack":2000,"isHero":false,"position":"SB"},{"seat":2,"name":"Polk","stack":2000,"isHero":false,"position":"BB"},{"seat":3,"name":"Dwan","stack":2000,"isHero":false,"position":"UTG"},{"seat":4,"name":"Selbst","stack":2000,"isHero":false,"position":"MP"},{"seat":5,"name":"Galfond","stack":2000,"isHero":false,"position":"CO"}],"holes":{"0":["As","Ks"],"3":["Qh","Qd"]},"actions":[{"street":"preflop","seat":3,"name":"Dwan","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"call","amount":60,"allIn":false},{"street":"flop","seat":3,"name":"Dwan","type":"bet","amount":80,"allIn":false},{"street":"flop","seat":0,"name":"You","type":"call","amount":80,"allIn":false},{"street":"turn","seat":3,"name":"Dwan","type":"check","amount":0,"allIn":false},{"street":"turn","seat":0,"name":"You","type":"check","amount":0,"allIn":false},{"street":"river","seat":3,"name":"Dwan","type":"check","amount":0,"allIn":false},{"street":"river","seat":0,"name":"You","type":"bet","amount":120,"allIn":false},{"street":"river","seat":3,"name":"Dwan","type":"call","amount":120,"allIn":false}],"board":["Ah","Kd","7c","2s","9h"],"potResults":[{"winners":[0],"amount":520,"potLabel":"Pot"}],"heroNet":260}';

const int kRefHandExportId = 178187040000001;

const List<RefFrame> kRefHandFrames = [
  RefFrame('Blinds 0.5/1 bb posted.', 'preflop', [], 30, [], false),
  RefFrame('Dwan raises to 3 bb', 'preflop', [], 90, [], false),
  RefFrame('You calls 3 bb', 'preflop', [], 150, [], false),
  RefFrame('Flop: Ah Kd 7c', 'flop', ['Ah', 'Kd', '7c'], 150, [], false),
  RefFrame('Dwan bets 4 bb', 'flop', ['Ah', 'Kd', '7c'], 230, [], false),
  RefFrame('You calls 4 bb', 'flop', ['Ah', 'Kd', '7c'], 310, [], false),
  RefFrame(
    'Turn: Ah Kd 7c 2s',
    'turn',
    ['Ah', 'Kd', '7c', '2s'],
    310,
    [],
    false,
  ),
  RefFrame('Dwan checks', 'turn', ['Ah', 'Kd', '7c', '2s'], 310, [], false),
  RefFrame('You checks', 'turn', ['Ah', 'Kd', '7c', '2s'], 310, [], false),
  RefFrame(
    'River: Ah Kd 7c 2s 9h',
    'river',
    ['Ah', 'Kd', '7c', '2s', '9h'],
    310,
    [],
    false,
  ),
  RefFrame(
    'Dwan checks',
    'river',
    ['Ah', 'Kd', '7c', '2s', '9h'],
    310,
    [],
    false,
  ),
  RefFrame(
    'You bets 6 bb',
    'river',
    ['Ah', 'Kd', '7c', '2s', '9h'],
    430,
    [],
    false,
  ),
  RefFrame(
    'Dwan calls 6 bb',
    'river',
    ['Ah', 'Kd', '7c', '2s', '9h'],
    550,
    [],
    false,
  ),
  RefFrame(
    'You win 26 bb.',
    'showdown',
    ['Ah', 'Kd', '7c', '2s', '9h'],
    550,
    [],
    true,
  ),
];

const String kRefFoldoutText =
    'PokerStars Hand #178187046000002: Hold\'em No Limit (10/20) - 2026/06/19 12:01:00 ET\nTable \'All-In Dojo\' 6-max Seat #1 is the button\nSeat 1: You (2000 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (2000 in chips)\nSeat 4: Dwan (2000 in chips)\nSeat 5: Selbst (2000 in chips)\nSeat 6: Galfond (2000 in chips)\nIvey: posts small blind 10\nPolk: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [7h 2c]\nDwan: raises 40 to 60\nSelbst: folds\nGalfond: folds\nYou: folds\nIvey: folds\nPolk: folds\nUncalled bet (40) returned to Dwan\nDwan collected 50 from pot\n*** SUMMARY ***\nTotal pot 50 | Rake 0\nSeat 1: You (button) folded before Flop\nSeat 2: Ivey (small blind) folded before Flop\nSeat 3: Polk (big blind) folded before Flop\nSeat 4: Dwan collected (50)\nSeat 5: Selbst folded before Flop\nSeat 6: Galfond folded before Flop';

const String kRefFoldoutJson =
    '{"id":2,"startedAt":1781870460000,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":2,"seats":[{"seat":0,"name":"You","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"Ivey","stack":2000,"isHero":false,"position":"SB"},{"seat":2,"name":"Polk","stack":2000,"isHero":false,"position":"BB"},{"seat":3,"name":"Dwan","stack":2000,"isHero":false,"position":"UTG"},{"seat":4,"name":"Selbst","stack":2000,"isHero":false,"position":"MP"},{"seat":5,"name":"Galfond","stack":2000,"isHero":false,"position":"CO"}],"holes":{"0":["7h","2c"],"3":["Ac","Ad"]},"actions":[{"street":"preflop","seat":3,"name":"Dwan","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":4,"name":"Selbst","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":5,"name":"Galfond","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":1,"name":"Ivey","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":2,"name":"Polk","type":"fold","amount":0,"allIn":false}],"board":[],"potResults":[{"winners":[3],"amount":90,"potLabel":"Pot"}],"heroNet":0}';

const int kRefFoldoutExportId = 178187046000002;

const List<RefFrame> kRefFoldoutFrames = [
  RefFrame('Blinds 0.5/1 bb posted.', 'preflop', [], 30, [], false),
  RefFrame('Dwan raises to 3 bb', 'preflop', [], 90, [], false),
  RefFrame('Selbst folds', 'preflop', [], 90, [4], false),
  RefFrame('Galfond folds', 'preflop', [], 90, [4, 5], false),
  RefFrame('You folds', 'preflop', [], 90, [4, 5, 0], false),
  RefFrame('Ivey folds', 'preflop', [], 90, [4, 5, 0, 1], false),
  RefFrame('Polk folds', 'preflop', [], 90, [4, 5, 0, 1, 2], false),
  RefFrame('Dwan win 4.5 bb.', 'preflop', [], 90, [4, 5, 0, 1, 2], true),
];

const String kRefAllinText =
    'PokerStars Hand #178187052000003: Hold\'em No Limit (10/20) - 2026/06/19 12:02:00 ET\nTable \'All-In Dojo\' 6-max Seat #3 is the button\nSeat 1: You (500 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (1200 in chips)\nSeat 4: Dwan (800 in chips)\nSeat 5: Selbst (3000 in chips)\nSeat 6: Galfond (2000 in chips)\nDwan: posts small blind 10\nSelbst: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [Jc Jd]\nGalfond: folds\nYou: raises 40 to 60\nIvey: raises 120 to 180\nPolk: folds\nDwan: raises 620 to 800 and is all-in\nSelbst: folds\nYou: calls 440 and is all-in\nIvey: calls 620\n*** FLOP *** [Kd Qs Th]\n*** TURN *** [Kd Qs Th] [Ac]\n*** RIVER *** [Kd Qs Th Ac] [Qh]\n*** SHOW DOWN ***\nYou: shows [Jc Jd] (a straight, Ace high)\nIvey: shows [Ac Kc] (two pair, Aces and Kings)\nDwan: shows [Ah Kh] (two pair, Aces and Kings)\nYou collected 510 from pot\nIvey collected 810 from pot\nDwan collected 810 from pot\n*** SUMMARY ***\nTotal pot 2130 | Rake 0\nBoard [Kd Qs Th Ac Qh]\nSeat 1: You showed [Jc Jd] and won (510) with a straight, Ace high\nSeat 2: Ivey showed [Ac Kc] and won (810) with two pair, Aces and Kings\nSeat 3: Polk (button) folded before Flop\nSeat 4: Dwan (small blind) showed [Ah Kh] and won (810) with two pair, Aces and Kings\nSeat 5: Selbst (big blind) folded before Flop\nSeat 6: Galfond folded before Flop';

const String kRefAllinJson =
    '{"id":103,"startedAt":1781870520000,"button":2,"sb":10,"bb":20,"sbSeat":3,"bbSeat":4,"seats":[{"seat":0,"name":"You","stack":500,"isHero":true,"position":"MP"},{"seat":1,"name":"Ivey","stack":2000,"isHero":false,"position":"CO"},{"seat":2,"name":"Polk","stack":1200,"isHero":false,"position":"BTN"},{"seat":3,"name":"Dwan","stack":800,"isHero":false,"position":"SB"},{"seat":4,"name":"Selbst","stack":3000,"isHero":false,"position":"BB"},{"seat":5,"name":"Galfond","stack":2000,"isHero":false,"position":"UTG"}],"holes":{"0":["Jc","Jd"],"1":["Ac","Kc"],"2":["9s","8s"],"3":["Ah","Kh"],"4":["3d","3c"],"5":["7h","2d"]},"actions":[{"street":"preflop","seat":5,"name":"Galfond","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":1,"name":"Ivey","type":"raise","amount":180,"allIn":false},{"street":"preflop","seat":2,"name":"Polk","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":3,"name":"Dwan","type":"raise","amount":800,"allIn":true},{"street":"preflop","seat":4,"name":"Selbst","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"call","amount":440,"allIn":true},{"street":"preflop","seat":1,"name":"Ivey","type":"call","amount":620,"allIn":false}],"board":["Kd","Qs","Th","Ac","Qh"],"potResults":[{"winners":[0,1,3],"amount":1530,"potLabel":"Main pot"},{"winners":[1,3],"amount":600,"potLabel":"Side pot 1"}],"heroNet":10}';

const int kRefAllinExportId = 178187052000003;

const List<RefFrame> kRefAllinFrames = [
  RefFrame('Blinds 0.5/1 bb posted.', 'preflop', [], 30, [], false),
  RefFrame('Galfond folds', 'preflop', [], 30, [5], false),
  RefFrame('You raises to 3 bb', 'preflop', [], 90, [5], false),
  RefFrame('Ivey raises to 9 bb', 'preflop', [], 270, [5], false),
  RefFrame('Polk folds', 'preflop', [], 270, [5, 2], false),
  RefFrame('Dwan raises to 40 bb (all-in)', 'preflop', [], 1060, [5, 2], false),
  RefFrame('Selbst folds', 'preflop', [], 1060, [5, 2, 4], false),
  RefFrame('You calls 22 bb (all-in)', 'preflop', [], 1500, [5, 2, 4], false),
  RefFrame('Ivey calls 31 bb', 'preflop', [], 2120, [5, 2, 4], false),
  RefFrame(
    'Flop: Kd Qs Th',
    'flop',
    ['Kd', 'Qs', 'Th'],
    2120,
    [5, 2, 4],
    false,
  ),
  RefFrame(
    'Turn: Kd Qs Th Ac',
    'turn',
    ['Kd', 'Qs', 'Th', 'Ac'],
    2120,
    [5, 2, 4],
    false,
  ),
  RefFrame(
    'River: Kd Qs Th Ac Qh',
    'river',
    ['Kd', 'Qs', 'Th', 'Ac', 'Qh'],
    2120,
    [5, 2, 4],
    false,
  ),
  RefFrame(
    'You, Ivey, Dwan win 106.5 bb.',
    'showdown',
    ['Kd', 'Qs', 'Th', 'Ac', 'Qh'],
    2120,
    [5, 2, 4],
    true,
  ),
];

const String kRefHuText =
    'PokerStars Hand #178187058000007: Hold\'em No Limit (10/20) - 2026/06/19 12:03:00 ET\nTable \'All-In Dojo\' 2-max Seat #2 is the button\nSeat 1: You (1500 in chips)\nSeat 2: Ivey (2500 in chips)\nIvey: posts small blind 10\nYou: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [Th 9h]\nIvey: raises 30 to 50\nYou: calls 30\n*** FLOP *** [8h 7c 2d]\nYou: checks\nIvey: bets 50\nYou: raises 125 to 175\nIvey: calls 125\n*** TURN *** [8h 7c 2d] [Ks]\nYou: bets 300\nIvey: raises 600 to 900\nYou: folds\nUncalled bet (600) returned to Ivey\nIvey collected 1050 from pot\n*** SUMMARY ***\nTotal pot 1050 | Rake 0\nBoard [8h 7c 2d Ks]\nSeat 1: You (big blind) folded on the Turn\nSeat 2: Ivey (small blind) collected (1050)';

const String kRefHuJson =
    '{"id":7,"startedAt":1781870580000,"button":1,"sb":10,"bb":20,"sbSeat":1,"bbSeat":0,"seats":[{"seat":0,"name":"You","stack":1500,"isHero":true,"position":"BB"},{"seat":1,"name":"Ivey","stack":2500,"isHero":false,"position":"BTN"}],"holes":{"0":["Th","9h"],"1":["Ad","4d"]},"actions":[{"street":"preflop","seat":1,"name":"Ivey","type":"raise","amount":50,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"call","amount":30,"allIn":false},{"street":"flop","seat":0,"name":"You","type":"check","amount":0,"allIn":false},{"street":"flop","seat":1,"name":"Ivey","type":"bet","amount":50,"allIn":false},{"street":"flop","seat":0,"name":"You","type":"raise","amount":175,"allIn":false},{"street":"flop","seat":1,"name":"Ivey","type":"call","amount":125,"allIn":false},{"street":"turn","seat":0,"name":"You","type":"bet","amount":300,"allIn":false},{"street":"turn","seat":1,"name":"Ivey","type":"raise","amount":900,"allIn":false},{"street":"turn","seat":0,"name":"You","type":"fold","amount":0,"allIn":false}],"board":["8h","7c","2d","Ks"],"potResults":[{"winners":[1],"amount":1650,"potLabel":"Pot"}],"heroNet":-525}';

const int kRefHuExportId = 178187058000007;

const List<RefFrame> kRefHuFrames = [
  RefFrame('Blinds 0.5/1 bb posted.', 'preflop', [], 30, [], false),
  RefFrame('Ivey raises to 2.5 bb', 'preflop', [], 70, [], false),
  RefFrame('You calls 1.5 bb', 'preflop', [], 100, [], false),
  RefFrame('Flop: 8h 7c 2d', 'flop', ['8h', '7c', '2d'], 100, [], false),
  RefFrame('You checks', 'flop', ['8h', '7c', '2d'], 100, [], false),
  RefFrame('Ivey bets 2.5 bb', 'flop', ['8h', '7c', '2d'], 150, [], false),
  RefFrame('You raises to 8.8 bb', 'flop', ['8h', '7c', '2d'], 325, [], false),
  RefFrame('Ivey calls 6.3 bb', 'flop', ['8h', '7c', '2d'], 450, [], false),
  RefFrame(
    'Turn: 8h 7c 2d Ks',
    'turn',
    ['8h', '7c', '2d', 'Ks'],
    450,
    [],
    false,
  ),
  RefFrame('You bets 15 bb', 'turn', ['8h', '7c', '2d', 'Ks'], 750, [], false),
  RefFrame(
    'Ivey raises to 45 bb',
    'turn',
    ['8h', '7c', '2d', 'Ks'],
    1650,
    [],
    false,
  ),
  RefFrame('You folds', 'turn', ['8h', '7c', '2d', 'Ks'], 1650, [0], false),
  RefFrame(
    'Ivey win 82.5 bb.',
    'turn',
    ['8h', '7c', '2d', 'Ks'],
    1650,
    [0],
    true,
  ),
];

const String kRefSplitText =
    'PokerStars Hand #178187064000009: Hold\'em No Limit (10/20) - 2026/06/19 12:04:00 ET\nTable \'All-In Dojo\' 3-max Seat #1 is the button\nSeat 1: You (2000 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (2000 in chips)\nIvey: posts small blind 10\nPolk: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [Ac Kd]\nYou: calls 20\nIvey: calls 10\nPolk: checks\n*** FLOP *** [Qs Jh Tc]\nIvey: bets 15\nPolk: calls 15\nYou: calls 15\n*** TURN *** [Qs Jh Tc] [2c]\nIvey: checks\nPolk: checks\nYou: checks\n*** RIVER *** [Qs Jh Tc 2c] [2d]\nIvey: checks\nPolk: checks\nYou: checks\n*** SHOW DOWN ***\nYou: shows [Ac Kd] (a straight, Ace high)\nIvey: shows [Ad Kc] (a straight, Ace high)\nPolk: shows [Ah Ks] (a straight, Ace high)\nYou collected 33 from pot\nIvey collected 33 from pot\nPolk collected 33 from pot\n*** SUMMARY ***\nTotal pot 99 | Rake 0\nBoard [Qs Jh Tc 2c 2d]\nSeat 1: You (button) showed [Ac Kd] and won (33) with a straight, Ace high\nSeat 2: Ivey (small blind) showed [Ad Kc] and won (33) with a straight, Ace high\nSeat 3: Polk (big blind) showed [Ah Ks] and won (33) with a straight, Ace high';

const String kRefSplitJson =
    '{"id":9,"startedAt":1781870640000,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":2,"seats":[{"seat":0,"name":"You","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"Ivey","stack":2000,"isHero":false,"position":"SB"},{"seat":2,"name":"Polk","stack":2000,"isHero":false,"position":"BB"}],"holes":{"0":["Ac","Kd"],"1":["Ad","Kc"],"2":["Ah","Ks"]},"actions":[{"street":"preflop","seat":0,"name":"You","type":"call","amount":20,"allIn":false},{"street":"preflop","seat":1,"name":"Ivey","type":"call","amount":10,"allIn":false},{"street":"preflop","seat":2,"name":"Polk","type":"check","amount":0,"allIn":false},{"street":"flop","seat":1,"name":"Ivey","type":"bet","amount":15,"allIn":false},{"street":"flop","seat":2,"name":"Polk","type":"call","amount":15,"allIn":false},{"street":"flop","seat":0,"name":"You","type":"call","amount":15,"allIn":false},{"street":"turn","seat":1,"name":"Ivey","type":"check","amount":0,"allIn":false},{"street":"turn","seat":2,"name":"Polk","type":"check","amount":0,"allIn":false},{"street":"turn","seat":0,"name":"You","type":"check","amount":0,"allIn":false},{"street":"river","seat":1,"name":"Ivey","type":"check","amount":0,"allIn":false},{"street":"river","seat":2,"name":"Polk","type":"check","amount":0,"allIn":false},{"street":"river","seat":0,"name":"You","type":"check","amount":0,"allIn":false}],"board":["Qs","Jh","Tc","2c","2d"],"potResults":[{"winners":[0,1,2],"amount":100,"potLabel":"Pot"}],"heroNet":0}';

const int kRefSplitExportId = 178187064000009;

const List<RefFrame> kRefSplitFrames = [
  RefFrame('Blinds 0.5/1 bb posted.', 'preflop', [], 30, [], false),
  RefFrame('You calls 1 bb', 'preflop', [], 50, [], false),
  RefFrame('Ivey calls 0.5 bb', 'preflop', [], 60, [], false),
  RefFrame('Polk checks', 'preflop', [], 60, [], false),
  RefFrame('Flop: Qs Jh Tc', 'flop', ['Qs', 'Jh', 'Tc'], 60, [], false),
  RefFrame('Ivey bets 0.8 bb', 'flop', ['Qs', 'Jh', 'Tc'], 75, [], false),
  RefFrame('Polk calls 0.8 bb', 'flop', ['Qs', 'Jh', 'Tc'], 90, [], false),
  RefFrame('You calls 0.8 bb', 'flop', ['Qs', 'Jh', 'Tc'], 105, [], false),
  RefFrame(
    'Turn: Qs Jh Tc 2c',
    'turn',
    ['Qs', 'Jh', 'Tc', '2c'],
    105,
    [],
    false,
  ),
  RefFrame('Ivey checks', 'turn', ['Qs', 'Jh', 'Tc', '2c'], 105, [], false),
  RefFrame('Polk checks', 'turn', ['Qs', 'Jh', 'Tc', '2c'], 105, [], false),
  RefFrame('You checks', 'turn', ['Qs', 'Jh', 'Tc', '2c'], 105, [], false),
  RefFrame(
    'River: Qs Jh Tc 2c 2d',
    'river',
    ['Qs', 'Jh', 'Tc', '2c', '2d'],
    105,
    [],
    false,
  ),
  RefFrame(
    'Ivey checks',
    'river',
    ['Qs', 'Jh', 'Tc', '2c', '2d'],
    105,
    [],
    false,
  ),
  RefFrame(
    'Polk checks',
    'river',
    ['Qs', 'Jh', 'Tc', '2c', '2d'],
    105,
    [],
    false,
  ),
  RefFrame(
    'You checks',
    'river',
    ['Qs', 'Jh', 'Tc', '2c', '2d'],
    105,
    [],
    false,
  ),
  RefFrame(
    'You, Ivey, Polk win 5 bb.',
    'showdown',
    ['Qs', 'Jh', 'Tc', '2c', '2d'],
    105,
    [],
    true,
  ),
];

const String kRefSessionText =
    'PokerStars Hand #178187040000001: Hold\'em No Limit (10/20) - 2026/06/19 12:00:00 ET\nTable \'All-In Dojo\' 6-max Seat #1 is the button\nSeat 1: You (2000 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (2000 in chips)\nSeat 4: Dwan (2000 in chips)\nSeat 5: Selbst (2000 in chips)\nSeat 6: Galfond (2000 in chips)\nIvey: posts small blind 10\nPolk: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [As Ks]\nDwan: raises 40 to 60\nYou: calls 60\n*** FLOP *** [Ah Kd 7c]\nDwan: bets 80\nYou: calls 80\n*** TURN *** [Ah Kd 7c] [2s]\nDwan: checks\nYou: checks\n*** RIVER *** [Ah Kd 7c 2s] [9h]\nDwan: checks\nYou: bets 120\nDwan: calls 120\n*** SHOW DOWN ***\nYou: shows [As Ks] (two pair, Aces and Kings)\nDwan: shows [Qh Qd] (a pair of Queens)\nYou collected 520 from pot\n*** SUMMARY ***\nTotal pot 520 | Rake 0\nBoard [Ah Kd 7c 2s 9h]\nSeat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings\nSeat 2: Ivey (small blind) folded before Flop\nSeat 3: Polk (big blind) folded before Flop\nSeat 4: Dwan showed [Qh Qd] and lost with a pair of Queens\nSeat 5: Selbst folded before Flop\nSeat 6: Galfond folded before Flop\n\n\nPokerStars Hand #178187046000002: Hold\'em No Limit (10/20) - 2026/06/19 12:01:00 ET\nTable \'All-In Dojo\' 6-max Seat #1 is the button\nSeat 1: You (2000 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (2000 in chips)\nSeat 4: Dwan (2000 in chips)\nSeat 5: Selbst (2000 in chips)\nSeat 6: Galfond (2000 in chips)\nIvey: posts small blind 10\nPolk: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [7h 2c]\nDwan: raises 40 to 60\nSelbst: folds\nGalfond: folds\nYou: folds\nIvey: folds\nPolk: folds\nUncalled bet (40) returned to Dwan\nDwan collected 50 from pot\n*** SUMMARY ***\nTotal pot 50 | Rake 0\nSeat 1: You (button) folded before Flop\nSeat 2: Ivey (small blind) folded before Flop\nSeat 3: Polk (big blind) folded before Flop\nSeat 4: Dwan collected (50)\nSeat 5: Selbst folded before Flop\nSeat 6: Galfond folded before Flop';

const String kRefUndefHolesJson =
    '{"id":2,"startedAt":1781870460000,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":2,"seats":[{"seat":0,"name":"You","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"Ivey","stack":2000,"isHero":false,"position":"SB"},{"seat":2,"name":"Polk","stack":2000,"isHero":false,"position":"BB"},{"seat":3,"name":"Dwan","stack":2000,"isHero":false,"position":"UTG"},{"seat":4,"name":"Selbst","stack":2000,"isHero":false,"position":"MP"},{"seat":5,"name":"Galfond","stack":2000,"isHero":false,"position":"CO"}],"holes":{"0":["7h","2c"],"3":["Ac","Ad"]},"actions":[{"street":"preflop","seat":3,"name":"Dwan","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":4,"name":"Selbst","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":5,"name":"Galfond","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":1,"name":"Ivey","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":2,"name":"Polk","type":"fold","amount":0,"allIn":false}],"board":[],"potResults":[{"winners":[3],"amount":90,"potLabel":"Pot"}],"heroNet":0}';

/// (hole, board, evaluator name, PokerStars descriptor)
const List<(List<String>, List<String>, String, String)> kRefPsHandNames = [
  (
    ['As', 'Ks'],
    ['Qs', 'Js', 'Ts', '2c', '3d'],
    'Royal Flush',
    'a royal flush',
  ),
  (
    ['9s', '8s'],
    ['7s', '6s', '5s', 'Ac', 'Kd'],
    'Straight Flush, Nine high',
    'a straight flush, Nine high',
  ),
  (
    ['Ac', 'Ad'],
    ['Ah', 'As', '2c', '3d', '9h'],
    'Four of a Kind, Aces',
    'four of a kind, Aces',
  ),
  (
    ['Ac', 'Ad'],
    ['Ah', 'Ks', 'Kc', '3d', '9h'],
    'Full House, Aces full of Kings',
    'a full house, Aces full of Kings',
  ),
  (
    ['Ac', '5c'],
    ['9c', 'Kc', '2c', '3d', '9h'],
    'Flush, Ace high',
    'a flush, Ace high',
  ),
  (
    ['9c', '8d'],
    ['7h', '6s', '5c', 'Ad', 'Kh'],
    'Straight, Nine high',
    'a straight, Nine high',
  ),
  (
    ['Qc', 'Qd'],
    ['Qh', '7s', '2c', '3d', '9h'],
    'Three of a Kind, Queens',
    'three of a kind, Queens',
  ),
  (
    ['As', 'Ks'],
    ['Ah', 'Kd', '7c', '2s', '9h'],
    'Two Pair, Aces & Kings',
    'two pair, Aces and Kings',
  ),
  (
    ['Qh', 'Qd'],
    ['Ah', 'Kd', '7c', '2s', '9h'],
    'Pair of Queens',
    'a pair of Queens',
  ),
  (['Jh', '3d'], ['Ah', 'Kd', '7c', '2s', '9h'], 'Ace High', 'high card Ace'),
  (
    ['Ac', '2d'],
    ['3h', '4d', '5c', '9s', 'Kh'],
    'Straight, Five high',
    'a straight, Five high',
  ),
];

const String kRefFracText =
    'PokerStars Hand #178187040000056: Hold\'em No Limit (0.25/0.5) - 2026/06/19 12:00:00 ET\nTable \'All-In Dojo\' 2-max Seat #2 is the button\nSeat 1: hero1 (50 in chips)\nSeat 2: villain (33.75 in chips)\nhero1: posts small blind 0.25\nvillain: posts big blind 0.5\n*** HOLE CARDS ***\nDealt to hero1 [Ah Ad]\nhero1: raises 1 to 1.5\nvillain: calls 1\n*** FLOP *** [Kc 7d 2h]\nvillain: checks\nhero1: bets 2.25\nvillain: folds\nUncalled bet (2.25) returned to hero1\nhero1 collected 2.75 from pot\n*** SUMMARY ***\nTotal pot 2.75 | Rake 0\nBoard [Kc 7d 2h]\nSeat 1: hero1 (small blind) collected (2.75)\nSeat 2: villain (big blind) folded on the Flop';

const String kRefFracJson =
    '{"id":123456,"startedAt":1781870400000,"button":1,"sb":0.25,"bb":0.5,"sbSeat":0,"bbSeat":1,"seats":[{"seat":0,"name":"hero1","stack":50,"isHero":true,"position":"SB"},{"seat":1,"name":"villain","stack":33.75,"isHero":false,"position":"BB"}],"holes":{"0":["Ah","Ad"]},"actions":[{"street":"preflop","seat":0,"name":"hero1","type":"raise","amount":1.5,"allIn":false},{"street":"preflop","seat":1,"name":"villain","type":"call","amount":1,"allIn":false},{"street":"flop","seat":1,"name":"villain","type":"check","amount":0,"allIn":false},{"street":"flop","seat":0,"name":"hero1","type":"bet","amount":2.25,"allIn":false},{"street":"flop","seat":1,"name":"villain","type":"fold","amount":0,"allIn":false}],"board":["Kc","7d","2h"],"potResults":[{"winners":[0],"amount":5,"potLabel":"Pot"}],"heroNet":3}';

const List<RefFrame> kRefFracFrames = [
  RefFrame('Blinds 0.5/1 bb posted.', 'preflop', [], 0.75, [], false),
  RefFrame('hero1 raises to 3 bb', 'preflop', [], 2, [], false),
  RefFrame('villain calls 2 bb', 'preflop', [], 3, [], false),
  RefFrame('Flop: Kc 7d 2h', 'flop', ['Kc', '7d', '2h'], 3, [], false),
  RefFrame('villain checks', 'flop', ['Kc', '7d', '2h'], 3, [], false),
  RefFrame('hero1 bets 4.5 bb', 'flop', ['Kc', '7d', '2h'], 5.25, [], false),
  RefFrame('villain folds', 'flop', ['Kc', '7d', '2h'], 5.25, [1], false),
  RefFrame('hero1 win 10 bb.', 'flop', ['Kc', '7d', '2h'], 5.25, [1], true),
];
