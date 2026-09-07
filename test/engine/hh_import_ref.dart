// GENERATED reference outputs computed by running the desktop TypeScript
// (src/lib/hhImport.ts + src/game/handHistory.ts) under Node 23 on the same
// fixtures in test/fixtures/. Do not hand-edit. `@@` marks the local-time
// startedAt (the tests substitute DateTime(...).millisecondsSinceEpoch so the
// pins are timezone independent).
// ignore_for_file: lines_longer_than_80_chars

const String kRefRoundTripText =
    'PokerStars Hand #178183800000007: Hold\'em No Limit (10/20) - 2026/06/19 12:00:00 ET\nTable \'All-In Dojo\' 6-max Seat #1 is the button\nSeat 1: You (2000 in chips)\nSeat 2: Ivey (2000 in chips)\nSeat 3: Polk (2000 in chips)\nSeat 4: Dwan (2000 in chips)\nSeat 5: Selbst (2000 in chips)\nSeat 6: Galfond (2000 in chips)\nIvey: posts small blind 10\nPolk: posts big blind 20\n*** HOLE CARDS ***\nDealt to You [As Ks]\nSelbst: folds\nGalfond: folds\nDwan: raises 40 to 60\nYou: calls 60\nIvey: folds\nPolk: folds\n*** FLOP *** [Ah Kd 7c]\nDwan: bets 80\nYou: calls 80\n*** TURN *** [Ah Kd 7c] [2s]\nDwan: checks\nYou: checks\n*** RIVER *** [Ah Kd 7c 2s] [9h]\nDwan: checks\nYou: bets 120\nDwan: calls 120\n*** SHOW DOWN ***\nYou: shows [As Ks] (two pair, Aces and Kings)\nDwan: shows [Qh Qd] (a pair of Queens)\nYou collected 520 from pot\n*** SUMMARY ***\nTotal pot 520 | Rake 0\nBoard [Ah Kd 7c 2s 9h]\nSeat 1: You (button) showed [As Ks] and won (520) with two pair, Aces and Kings\nSeat 2: Ivey (small blind) folded before Flop\nSeat 3: Polk (big blind) folded before Flop\nSeat 4: Dwan showed [Qh Qd] and lost with a pair of Queens\nSeat 5: Selbst folded before Flop\nSeat 6: Galfond folded before Flop';

const String kRefRoundTripJson =
    '{"id":7,"startedAt":@@,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":2,"seats":[{"seat":0,"name":"You","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"Ivey","stack":2000,"isHero":false,"position":"SB"},{"seat":2,"name":"Polk","stack":2000,"isHero":false,"position":"BB"},{"seat":3,"name":"Dwan","stack":2000,"isHero":false,"position":"UTG"},{"seat":4,"name":"Selbst","stack":2000,"isHero":false,"position":"MP"},{"seat":5,"name":"Galfond","stack":2000,"isHero":false,"position":"CO"}],"holes":{"0":["As","Ks"],"3":["Qh","Qd"]},"actions":[{"street":"preflop","seat":4,"name":"Selbst","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":5,"name":"Galfond","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":3,"name":"Dwan","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":0,"name":"You","type":"call","amount":60,"allIn":false},{"street":"preflop","seat":1,"name":"Ivey","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":2,"name":"Polk","type":"fold","amount":0,"allIn":false},{"street":"flop","seat":3,"name":"Dwan","type":"bet","amount":80,"allIn":false},{"street":"flop","seat":0,"name":"You","type":"call","amount":80,"allIn":false},{"street":"turn","seat":3,"name":"Dwan","type":"check","amount":0,"allIn":false},{"street":"turn","seat":0,"name":"You","type":"check","amount":0,"allIn":false},{"street":"river","seat":3,"name":"Dwan","type":"check","amount":0,"allIn":false},{"street":"river","seat":0,"name":"You","type":"bet","amount":120,"allIn":false},{"street":"river","seat":3,"name":"Dwan","type":"call","amount":120,"allIn":false}],"board":["Ah","Kd","7c","2s","9h"],"potResults":[{"winners":[0],"amount":520,"potLabel":"Pot"}],"heroNet":520,"imported":true,"heroName":"You"}';

const String kRefRealJson =
    '{"id":799999,"startedAt":@@,"button":2,"sb":0.05,"bb":0.1,"sbSeat":4,"bbSeat":0,"seats":[{"seat":0,"name":"villain_a","stack":10,"isHero":false,"position":"SB"},{"seat":2,"name":"hero_name","stack":12.35,"isHero":true,"position":"BTN"},{"seat":4,"name":"villain_b","stack":9.4,"isHero":false,"position":"BB"}],"holes":{"0":["Qd","Th"],"2":["Jh","Jc"]},"actions":[{"street":"preflop","seat":2,"name":"hero_name","type":"raise","amount":0.3,"allIn":false},{"street":"preflop","seat":4,"name":"villain_b","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":0,"name":"villain_a","type":"call","amount":0.2,"allIn":false},{"street":"flop","seat":0,"name":"villain_a","type":"check","amount":0,"allIn":false},{"street":"flop","seat":2,"name":"hero_name","type":"bet","amount":0.45,"allIn":false},{"street":"flop","seat":0,"name":"villain_a","type":"call","amount":0.45,"allIn":false},{"street":"turn","seat":0,"name":"villain_a","type":"check","amount":0,"allIn":false},{"street":"turn","seat":2,"name":"hero_name","type":"check","amount":0,"allIn":false},{"street":"river","seat":0,"name":"villain_a","type":"bet","amount":1.55,"allIn":false},{"street":"river","seat":2,"name":"hero_name","type":"call","amount":1.55,"allIn":false}],"board":["2d","7s","Td","Qc","3h"],"potResults":[{"winners":[0],"amount":4.53,"potLabel":"Pot"}],"heroNet":0,"imported":true,"heroName":"hero_name"}';

const String kRefBadJson =
    '{"id":1,"startedAt":@@,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":0,"seats":[{"seat":0,"name":"hero","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"v1","stack":2000,"isHero":false,"position":"BB"}],"holes":{"0":["7h","2c"]},"actions":[{"street":"preflop","seat":1,"name":"v1","type":"raise","amount":2000,"allIn":false},{"street":"preflop","seat":0,"name":"hero","type":"call","amount":1980,"allIn":false}],"board":[],"potResults":[],"heroNet":0,"imported":true,"heroName":"hero"}';

const List<String> kRefMultiJson = [
  '{"id":2,"startedAt":@@,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":2,"seats":[{"seat":0,"name":"v1","stack":5000,"isHero":false,"position":"BTN"},{"seat":1,"name":"v2","stack":5000,"isHero":false,"position":"SB"},{"seat":2,"name":"hero","stack":5000,"isHero":true,"position":"BB"}],"holes":{"0":["Ts","9s"],"2":["7h","2c"]},"actions":[{"street":"preflop","seat":0,"name":"v1","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":1,"name":"v2","type":"fold","amount":0,"allIn":false},{"street":"preflop","seat":2,"name":"hero","type":"call","amount":40,"allIn":false},{"street":"flop","seat":2,"name":"hero","type":"check","amount":0,"allIn":false},{"street":"flop","seat":0,"name":"v1","type":"bet","amount":500,"allIn":false},{"street":"flop","seat":2,"name":"hero","type":"call","amount":500,"allIn":false},{"street":"turn","seat":2,"name":"hero","type":"check","amount":0,"allIn":false},{"street":"turn","seat":0,"name":"v1","type":"bet","amount":1000,"allIn":false},{"street":"turn","seat":2,"name":"hero","type":"call","amount":1000,"allIn":false},{"street":"river","seat":2,"name":"hero","type":"check","amount":0,"allIn":false},{"street":"river","seat":0,"name":"v1","type":"bet","amount":300,"allIn":false},{"street":"river","seat":2,"name":"hero","type":"call","amount":300,"allIn":false}],"board":["As","Ks","Qs","Js","2d"],"potResults":[{"winners":[0],"amount":3730,"potLabel":"Pot"}],"heroNet":0,"imported":true,"heroName":"hero"}',
  '{"id":3,"startedAt":@@,"button":1,"sb":10,"bb":20,"sbSeat":1,"bbSeat":3,"seats":[{"seat":1,"name":"hero","stack":2000,"isHero":true,"position":"BTN"},{"seat":3,"name":"v1","stack":2000,"isHero":false,"position":"BTN"}],"holes":{"1":["Ah","Ad"],"3":["Kc","Qc"]},"actions":[{"street":"preflop","seat":1,"name":"hero","type":"raise","amount":60,"allIn":false},{"street":"preflop","seat":3,"name":"v1","type":"raise","amount":2000,"allIn":true},{"street":"preflop","seat":1,"name":"hero","type":"call","amount":1940,"allIn":true}],"board":["2c","3d","8h","9c","Kd"],"potResults":[{"winners":[1],"amount":4000,"potLabel":"Pot"}],"heroNet":4000,"imported":true,"heroName":"hero"}',
];

const int kRefMultiSkipped = 1;

/// analyzeImported results after overriding startedAt to 1781000000000 + i*1000
/// (leaks serialised without ts).
const Map<String, ({int reviewed, List<String> leaks})> kRefAnalysis = {
  'roundTrip': (reviewed: 2, leaks: []),
  'real': (reviewed: 1, leaks: []),
  'bad': (
    reviewed: 1,
    leaks: [
      '{"id":"imp-1781000000000-preflop","street":"preflop","heroPos":"BTN","hole":["7h","2c"],"board":[],"pot":101,"toCall":99,"bb":1,"oppActive":["BB"],"options":[{"action":"fold","label":"Fold"},{"action":"call","label":"Call 99.0 bb","amount":99}],"best":"fold","rationale":"Imported hand: you called 99.0 bb needing 50% but 72o wins only ~36% even against a random hand — real ranges make it worse.","equity":0.3584,"potOdds":0.495}',
    ],
  ),
  'multi': (
    reviewed: 5,
    leaks: [
      '{"id":"imp-1781000000000-flop","street":"flop","heroPos":"BB","hole":["7h","2c"],"board":["As","Ks","Qs"],"pot":31.5,"toCall":25,"bb":1,"oppActive":["BTN","SB"],"options":[{"action":"fold","label":"Fold"},{"action":"call","label":"Call 25.0 bb","amount":25}],"best":"fold","rationale":"Imported hand: you called 25.0 bb needing 44% but 72o wins only ~19% even against a random hand — real ranges make it worse.","equity":0.193,"potOdds":0.4424778761061947}',
      '{"id":"imp-1781000000000-turn","street":"turn","heroPos":"BB","hole":["7h","2c"],"board":["As","Ks","Qs","Js"],"pot":106.5,"toCall":50,"bb":1,"oppActive":["BTN","SB"],"options":[{"action":"fold","label":"Fold"},{"action":"call","label":"Call 50.0 bb","amount":50}],"best":"fold","rationale":"Imported hand: you called 50.0 bb needing 32% but 72o wins only ~17% even against a random hand — real ranges make it worse.","equity":0.1714,"potOdds":0.3194888178913738}',
    ],
  ),
};

const Map<String, int> kRefSeeds = {
  'bad': 816318510,
  'real': 350071127,
  'multiFlop': 3753743130,
};

const String kRefCrlfJson =
    '{"id":1,"startedAt":@@,"button":0,"sb":10,"bb":20,"sbSeat":1,"bbSeat":0,"seats":[{"seat":0,"name":"hero","stack":2000,"isHero":true,"position":"BTN"},{"seat":1,"name":"v1","stack":2000,"isHero":false,"position":"BB"}],"holes":{"0":["7h","2c"]},"actions":[{"street":"preflop","seat":1,"name":"v1","type":"raise","amount":2000,"allIn":false},{"street":"preflop","seat":0,"name":"hero","type":"call","amount":1980,"allIn":false}],"board":[],"potResults":[],"heroNet":0,"imported":true,"heroName":"hero"}';

const String kRefNoDateJson =
    '{"id":77,"startedAt":@@,"button":1,"sb":1,"bb":2,"sbSeat":2,"bbSeat":0,"seats":[{"seat":0,"name":"a","stack":100,"isHero":false,"position":"BB"},{"seat":1,"name":"b","stack":200,"isHero":false,"position":"BTN"},{"seat":2,"name":"c","stack":300,"isHero":false,"position":"SB"}],"holes":{},"actions":[],"board":[],"potResults":[],"heroNet":0,"imported":true,"heroName":null}';

const List<String> kRefNegOffPositions = ['0:MP', '1:MP', '8:BTN'];

const List<String> kRefTenSeatPositions = [
  '0:BTN',
  '1:SB',
  '2:BB',
  '3:UTG',
  '4:MP',
  '5:CO',
  '6:MP',
  '7:MP',
  '8:CO',
  '9:CO',
];

const String kRefCommaAmountsJson =
    '{"id":9,"startedAt":@@,"button":0,"sb":1000,"bb":2000,"sbSeat":0,"bbSeat":1,"seats":[{"seat":0,"name":"a","stack":1234.5,"isHero":true,"position":"BTN"},{"seat":1,"name":"b","stack":100,"isHero":false,"position":"BB"}],"holes":{"0":["Ah","Kh"]},"actions":[{"street":"preflop","seat":0,"name":"a","type":"raise","amount":4000,"allIn":false},{"street":"preflop","seat":1,"name":"b","type":"call","amount":2000,"allIn":true}],"board":[],"potResults":[],"heroNet":0,"imported":true,"heroName":"a"}';

const int kRefBigId = 799999;
const int kRefSmallId = 42;
