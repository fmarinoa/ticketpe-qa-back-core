// Capa del proyecto: ambientes, credenciales y timeouts.
// Depende de `utils` / `auth` que expone karate-base.js.
// https://docs.karatelabs.io/core-syntax/configuration

function fn() {
  var env = karate.env;
  var isCi = karate.properties['ci'] === 'true';

  var baseUrl = utils.loadConfig('baseUrl');

  if (!baseUrl) {
    throw 'ambiente desconocido: ' + env + ' (usar -Dkarate.env=prod|stag|local)';
  }

  karate.log('ambiente:', env, '| baseUrl:', baseUrl, '| ci:', isCi);

  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);
  karate.configure('retry', { count: 3, interval: 1000 });

  karate.configure('headers', { 'X-Request-Id': traceId });

  karate.configure('logPrettyRequest', !isCi);
  karate.configure('logPrettyResponse', !isCi);

  return {
    env: env,
    isCi: isCi,
    baseUrl: baseUrl,
    ticketpe: {
      cards: utils.loadConfig('cards'),
      roles: utils.loadConfig('roles'),
      password: utils.randomPassword(),
      newEmail: function () {
        return 'qa.karate.' + java.util.UUID.randomUUID() + '@testingperu.com';
      }
    }
  };
}
