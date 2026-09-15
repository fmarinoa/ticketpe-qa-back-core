@cotizacion
Feature: Cotización de compra (sin reservar cupo)

Background:
  * url baseUrl
  * def elegido = callonce read('helpers/evento-vendible.feature')

@smoke
Scenario: la cotización calcula subtotal, IGV (18%) y total
  Given path 'cotizaciones'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2 }
  When method post
  Then status 200
  And match response contains { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 2, precio_unitario: '#(elegido.precio)', descuento: 0, cupon_aplicado: null }
  * def esperadoSubtotal = elegido.precio * 2
  * def redondear = function(n){ return Math.round(n * 100) / 100 }
  And match redondear(response.subtotal) == redondear(esperadoSubtotal)
  And match redondear(response.igv) == redondear((response.subtotal - response.descuento) * 0.18)
  And match redondear(response.total) == redondear(response.subtotal - response.descuento + response.igv)

Scenario Outline: la cotización valida la entrada: <caso>
  Given path 'cotizaciones'
  And request <cuerpo>
  When method post
  Then status 400
  And match response.error == 'entrada_invalida'

  Examples:
    | caso          | cuerpo                                                      |
    | cuerpo vacío  | {}                                                          |
    | tipo numérico | { evento_id: '#(elegido.evento_id)', tipo: 1, cantidad: 1 }  |

@datos
Scenario Outline: la cotización rechaza una cantidad <caso>
  Given path 'cotizaciones'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: '#(cantidad)' }
  When method post
  Then status 400
  And match response.error == 'entrada_invalida'
  And match response.detalle.fieldErrors.cantidad == '#present'

  Examples:
    | read('classpath:ticketpe/data/cotizaciones-cantidad-invalida.json') |

Scenario: cotizar un tipo de entrada que no existe en el evento
  Given path 'cotizaciones'
  And request { evento_id: '#(elegido.evento_id)', tipo: 'Tipo Inexistente QA', cantidad: 1 }
  When method post
  Then status 404
  And match response.error == 'no_encontrado'

Scenario: cotizar un evento inexistente
  Given path 'cotizaciones'
  And request { evento_id: 999999, tipo: 'General', cantidad: 1 }
  When method post
  Then status 404
  And match response.error == 'no_encontrado'

@negocio
Scenario: la cotización no valida el cupo disponible (documenta el comportamiento actual)
  Given path 'cotizaciones'
  And request { evento_id: '#(elegido.evento_id)', tipo: '#(elegido.tipo)', cantidad: 99999 }
  When method post
  Then status 200
  And match response.cantidad == 99999
