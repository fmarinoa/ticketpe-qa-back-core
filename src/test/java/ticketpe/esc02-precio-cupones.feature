@ESC02 @dinero @RIESGO-ALTO
Feature: ESC02 - Cálculo de precio y cupones

Background:
  * url baseUrl
  * def eventoPropio = ticketpe.roles.organizer.evento_id

@TC-API-02 @REQ-HU-E3.1 @api @p1 @alto @funcional @datos
Scenario Outline: CP05 - desglose de la cotización al céntimo exacto: <caso>
  * def cupon = call read('helpers/cupon.feature') { valor: '#(valor)' }
  Given path 'cotizaciones'
  And request { evento_id: '#(eventoPropio)', tipo: '#(tipo)', cantidad: '#(cantidad)', cupon: '#(cupon.codigo)' }
  When method post
  Then status 200
  # si el precio del tipo cambió en el ambiente, este match lo dice antes que el desglose
  And match response.precio_unitario == precio
  And match response contains { subtotal: '#(subtotal)', descuento: '#(descuento)', igv: '#(igv)', total: '#(total)', moneda: 'PEN' }

  Examples:
    | read('classpath:ticketpe/data/cotizacion-desglose.json') |

@TC-API-08 @REQ-HU-E3.1 @api @p2 @alto @funcional
Scenario Outline: CP06 - un cupón <caso> no da descuento ni en cotización ni en reserva
  * def vencido = callonce read('helpers/cupon.feature') { vigente_desde: '2025-01-01T00:00:00Z', vigente_hasta: '2025-02-01T00:00:00Z' }
  * def agotado = callonce read('helpers/cupon-agotado.feature')
  * def vigente = callonce read('helpers/cupon.feature')
  * def ajeno = callonce read('helpers/evento-vendible.feature') { excluirEvento: '#(eventoPropio)' }
  * def evento = <evento>
  * def codigo = <codigo>

  Given path 'cotizaciones'
  And request { evento_id: '#(evento.evento_id)', tipo: '#(evento.tipo)', cantidad: 1 }
  When method post
  Then status 200
  * def sinCupon = response

  Given path 'cotizaciones'
  And request { evento_id: '#(evento.evento_id)', tipo: '#(evento.tipo)', cantidad: 1, cupon: '#(codigo)' }
  When method post
  And match response.error == 'cupon_invalido'
  And match karate.get('response.descuento', 0) == 0
  And assert karate.get('response.total', sinCupon.total) >= sinCupon.total

  * def comprador = call read('helpers/usuario.feature')
  * configure headers = auth.bearer(comprador.token)
  Given path 'reservas'
  And request { evento_id: '#(evento.evento_id)', tipo: '#(evento.tipo)', cantidad: 1 }
  When method post
  Then status 201
  * def reservaId = response.reserva.id

  Given path 'reservas', reservaId, 'cupon'
  And request { codigo: '#(codigo)' }
  When method post
  And match response.error == 'cupon_invalido'

  Given path 'reservas', reservaId
  When method get
  Then status 200
  And match response.reserva.cupon_codigo == null

  Examples:
    | caso                         | codigo                  | evento                                                        |
    | inexistente                  | 'CUPON-QA-INEXISTENTE'  | { evento_id: '#(eventoPropio)', tipo: 'General' }             |
    | vencido                      | vencido.codigo          | { evento_id: '#(eventoPropio)', tipo: 'General' }             |
    | agotado                      | agotado.codigo          | { evento_id: '#(eventoPropio)', tipo: 'General' }             |
    | de otro evento               | vigente.codigo          | ajeno                                                         |

@TC-API-09 @REQ-HU-E3.3 @api @p1 @alto @funcional
Scenario: CP07 - no se apilan dos cupones sobre la misma reserva
  * def primero = call read('helpers/cupon.feature') { valor: 10 }
  * def segundo = call read('helpers/cupon.feature') { valor: 15 }
  * def comprador = call read('helpers/usuario.feature')

  Given path 'cotizaciones'
  And request { evento_id: '#(eventoPropio)', tipo: 'General', cantidad: 1, cupon: '#(primero.codigo)' }
  When method post
  Then status 200
  * def conPrimerCupon = response

  * configure headers = auth.bearer(comprador.token)
  Given path 'reservas'
  And request { evento_id: '#(eventoPropio)', tipo: 'General', cantidad: 1 }
  When method post
  Then status 201
  * def reserva = response.reserva

  Given path 'reservas', reserva.id, 'cupon'
  And request { codigo: '#(primero.codigo)' }
  When method post
  Then status 200

  Given path 'reservas', reserva.id, 'cupon'
  And request { codigo: '#(primero.codigo)' }
  When method post
  Then status 409
  And match response.error == 'cupon_ya_aplicado'

  Given path 'reservas', reserva.id, 'cupon'
  And request { codigo: '#(segundo.codigo)' }
  When method post
  Then status 409
  And match response.error == 'cupon_ya_aplicado'

  Given path 'reservas', reserva.id
  When method get
  Then status 200
  And match response.reserva.expira_en == reserva.expira_en

  Given path 'reservas', reserva.id, 'pago'
  And request { tarjeta_prueba: '#(ticketpe.cards.approved)' }
  When method post
  Then status 201
  And match response.pago.monto == conPrimerCupon.total
