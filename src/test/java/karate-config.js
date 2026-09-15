// https://testathon.testingperu.com/api/core

function fn() {
  var config = {
    baseUrl: karate.properties['baseUrl'],
    password: 'Qa123456',
    tarjetaAprobada: '4242424242424242',
    tarjetaRechazada: '4000000000000002'
  };
  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);
  return config;
}
