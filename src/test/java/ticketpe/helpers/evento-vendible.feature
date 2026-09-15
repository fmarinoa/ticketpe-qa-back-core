@ignore
Feature: elige un evento futuro, pagado y con cupo (helper reutilizable)

Scenario: elegir
  * def cantidad = karate.get('cantidad', 1)
  Given url baseUrl
  And path 'eventos'
  When method get
  Then status 200
  * def ahora = java.time.Instant.now().toString()
  * def futurosPagados = response.eventos.filter(function(e){ return !e.es_gratuito && e.fecha_inicio > ahora })
  * def elegir =
    """
    function(eventos) {
      for (var i = 0; i < eventos.length; i++) {
        var tipos = karate.call('classpath:ticketpe/helpers/disponibilidad.feature', { evento_id: eventos[i].id }).disponibilidad;
        for (var j = 0; j < tipos.length; j++) {
          var t = tipos[j];
          if (t.venta_abierta && t.precio > 0 && t.disponible >= cantidad) {
            return { evento_id: eventos[i].id, tipo: t.nombre, precio: t.precio, tipo_entrada_id: t.tipo_entrada_id, disponible: t.disponible };
          }
        }
      }
      return null;
    }
    """
  * def elegido = elegir(futurosPagados)
  * match elegido != null
  * def evento_id = elegido.evento_id
  * def tipo = elegido.tipo
  * def precio = elegido.precio
