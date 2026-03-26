document.addEventListener('DOMContentLoaded', function () {
  var pattern = /w(\d+)-t(\d+)/;

  document.querySelectorAll('p').forEach(function (p) {
    p.addEventListener('click', function () {
      var span = p.querySelector('span');
      if (!span) return;

      var spanId = span.getAttribute('id') || '';
      var patternArray = spanId.match(pattern);
      if (!patternArray) return;

      var team = patternArray[2];
      var routesTo = p.getAttribute('data-routes-to');
      if (!routesTo) return;

      var nextGameNumber = parseInt(routesTo, 10);
      if (!nextGameNumber) return;

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
