function fn() {
  var environments = {
    prod: 'https://testathon.testingperu.com/api/core',
    stag: 'https://testathon.stag.testingperu.com/api/core',
    local: 'http://localhost:4100/api/core'
  };

  var testCards = {
    prod: { approved: '4242424242424242', declined: '4000000000000002' },
    stag: { approved: '4242424242424242', declined: '4000000000000002' },
    local: { approved: '4242424242424242', declined: '4000000000000002' }
  };

  // -Denvironment=local ó -Dkarate.env=local
  var env = karate.properties['environment'] || karate.env;
  var baseUrl = environments[env];
  if (!baseUrl) {
    karate.fail('ambiente desconocido: ' + env + '. Válidos: ' + Object.keys(environments));
  }

  karate.log('ambiente:', env);
  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);

  return {
    env,
    baseUrl,
    password: 'Qa123456',
    cards: testCards[env]
  };
}
