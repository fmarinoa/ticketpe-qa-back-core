function fn() {
  var ambientes = {
    testathon: 'https://testathon.testingperu.com/api/core',
    local: 'http://localhost:4100/api/core'
  };
  // -Denvironment=local, -Dkarate.env=local o la variable de entorno KARATE_ENV
  var env = karate.properties['environment'] || karate.env || 'testathon';
  var baseUrl = karate.properties['baseUrl'] || ambientes[env];
  if (!baseUrl) {
    karate.fail('ambiente desconocido: ' + env + '. Válidos: ' + Object.keys(ambientes));
  }
  karate.log('ambiente:', env, '| baseUrl:', baseUrl);
  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);
  return {
    env: env,
    baseUrl: baseUrl,
    password: 'Qa123456',
    tarjetaAprobada: '4242424242424242',
    tarjetaRechazada: '4000000000000002'
  };
}
