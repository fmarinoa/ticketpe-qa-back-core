@ignore
Feature: dos pagos simultáneos de la misma reserva con la misma Idempotency-Key (helper reutilizable)

  Karate no dispara requests en paralelo dentro de un escenario: se usa el
  HttpClient de Java. Estas dos llamadas no aparecen en el reporte HTML.

Scenario: pagar en paralelo
  * def pagar =
    """
    function() {
      var HttpClient = Java.type('java.net.http.HttpClient');
      var HttpRequest = Java.type('java.net.http.HttpRequest');
      var HttpResponse = Java.type('java.net.http.HttpResponse');
      var peticion = HttpRequest.newBuilder(java.net.URI.create(baseUrl + '/reservas/' + reserva_id + '/pago'))
        .header('Content-Type', 'application/json')
        .header('Authorization', 'Bearer ' + token)
        .header('Idempotency-Key', clave)
        .header('X-Request-Id', traceId)
        .POST(HttpRequest.BodyPublishers.ofString(JSON.stringify({ tarjeta_prueba: ticketpe.cards.approved })))
        .build();
      var cliente = HttpClient.newHttpClient();
      var enVuelo = [cliente.sendAsync(peticion, HttpResponse.BodyHandlers.ofString()),
                     cliente.sendAsync(peticion, HttpResponse.BodyHandlers.ofString())];
      return enVuelo.map(function(f) { var r = f.join(); return { status: r.statusCode(), body: JSON.parse(r.body()) }; });
    }
    """
  * def respuestas = pagar()
