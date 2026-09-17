@ignore
Feature: el mismo POST enviado en paralelo, uno por token (helper reutilizable)

  Karate no dispara requests en paralelo dentro de un escenario: se usa el
  HttpClient de Java. Estas llamadas no aparecen en el reporte HTML.
  Entrada: ruta (relativa a baseUrl), cuerpo, tokens (uno por request).

Scenario: enviar en paralelo
  * def enviar =
    """
    function() {
      var HttpClient = Java.type('java.net.http.HttpClient');
      var HttpRequest = Java.type('java.net.http.HttpRequest');
      var HttpResponse = Java.type('java.net.http.HttpResponse');
      var cliente = HttpClient.newHttpClient();
      var enVuelo = tokens.map(function(t) {
        var peticion = HttpRequest.newBuilder(java.net.URI.create(baseUrl + '/' + ruta))
          .header('Content-Type', 'application/json')
          .header('Authorization', 'Bearer ' + t)
          .header('X-Request-Id', traceId)
          .POST(HttpRequest.BodyPublishers.ofString(JSON.stringify(cuerpo)))
          .build();
        return cliente.sendAsync(peticion, HttpResponse.BodyHandlers.ofString());
      });
      return enVuelo.map(function(f) { var r = f.join(); return { status: r.statusCode(), body: JSON.parse(r.body()) }; });
    }
    """
  * def respuestas = enviar()
  * def estados = karate.map(respuestas, function(r){ return r.status })
