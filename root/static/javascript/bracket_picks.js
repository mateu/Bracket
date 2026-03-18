document.addEventListener('DOMContentLoaded', function () {
  var pattern = /r(\d+)-t(\d+)-rg(\d+)/;

  document.querySelectorAll('p').forEach(function (p) {
    p.addEventListener('click', function () {
      var span = p.querySelector('span');
      if (!span) return;

      var spanId = span.getAttribute('id') || '';
      var patternArray = spanId.match(pattern);
      if (!patternArray) return;

      var round = parseInt(patternArray[1], 10) + 1;
      var team = patternArray[2];
      var region = patternArray[3];
      var newId = 'r' + round + '-t' + team + '-rg' + region;
      var game = advance_team(parseInt(team, 10), round, parseInt(region, 10));
      var pickGame = 'p' + game;

      var nextGame = document.querySelector('#w' + game);
      if (!nextGame) return;

      nextGame.innerHTML =
        p.textContent +
        '<span id="' +
        newId +
        '"><input type="hidden" name="' +
        pickGame +
        '" value="' +
        team +
        '" /></span>';
    });
  });
});

function advance_team(team, round, region) {
  var region_addend = 15 * (region - 1);
  var round_addend;
  if (round == 0) {
    round_addend = 0;
  } else if (round == 1) {
    round_addend = 0;
  } else if (round == 2) {
    round_addend = 8;
  } else if (round == 3) {
    round_addend = 12;
  } else if (round == 4) {
    round_addend = 14;
  }
  var divisor = Math.pow(2, round);
  var team_addend = parseInt((team - 16 * (region - 1)) / divisor, 10);
  var result = team_addend + round_addend + region_addend;
  if (team % divisor != 0) {
    result += 1;
  }
  return result;
}
