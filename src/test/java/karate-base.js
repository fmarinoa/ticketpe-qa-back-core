// Capa genérica del framework, sin conocimiento del proyecto.
// Karate la evalúa ANTES de karate-config.js
// https://docs.karatelabs.io/core-syntax/configuration/#advanced-karate-basejs

function fn() {
  var traceId = 'testitans-' + java.util.UUID.randomUUID();

  return {
    traceId: traceId,
    utils: {
      loadConfig: function (nombre) {
        return karate.read('classpath:config/' + nombre + '.json')[karate.env];
      },
      round: function (n, decimales) {
        var factor = Math.pow(10, decimales === undefined ? 2 : decimales);
        return Math.round(n * factor) / factor;
      },
      randomPassword: function () {
        return String(java.util.UUID.randomUUID()).split('-').join('').substring(0, 13);
      },
      // ISO-8601 UTC; Karate v2 convierte Instant a Date JS y su toString no es ISO
      now: function () {
        return new Date().toISOString();
      },
      minutesBetween: function (desde, hasta) {
        var ms = java.time.Instant.parse(hasta).toEpochMilli()
               - java.time.Instant.parse(desde).toEpochMilli();
        return ms / 60000;
      }
    },
    auth: {
      bearer: function (token) {
        return { Authorization: 'Bearer ' + token, 'X-Request-Id': traceId };
      }
    }
  };
}
