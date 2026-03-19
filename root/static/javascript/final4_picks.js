document.addEventListener('DOMContentLoaded', function () {
  var pattern = /w(\d+)-t(\d+)/;

  document.querySelectorAll('p').forEach(function (p) {
    p.addEventListener('click', function () {
      var span = p.querySelector('span');
      if (!span) return;

      var spanId = span.getAttribute('id') || '';
      var patternArray = spanId.match(pattern);
      if (!patternArray) return;

      var gameNumber = parseInt(patternArray[1], 10);
      var team = patternArray[2];
      var nextGameNumber;

      if (gameNumber == 15 || gameNumber == 30) {
        nextGameNumber = 61;
      } else if (gameNumber == 45 || gameNumber == 60) {
        nextGameNumber = 62;
      } else if (gameNumber == 61 || gameNumber == 62) {
        nextGameNumber = 63;
      } else {
        return;
      }

      var newId = 'w' + nextGameNumber + '-t' + team;
      var pickGame = 'p' + nextGameNumber;
      var nextGame = document.querySelector('#w' + nextGameNumber);
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
