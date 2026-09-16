@ESC01 @autorizacion @RIESGO-CRITICO
Feature: ESC01 - Control de acceso por rol y token

Background:
  * url baseUrl
  * def dueno = callonce read('helpers/usuario.feature')
  * def org = callonce read('helpers/login.feature') { role: 'organizer' }
  * def admin = callonce read('helpers/login.feature') { role: 'admin' }
  * def eventoPropio = ticketpe.roles.organizer.evento_id

@TC-API-01 @REQ-HU-E1.3 @api @p1 @critico @seguridad
Scenario Outline: CP01 - ningún rol entra a un endpoint ajeno: <caso>
  * def propia = callonce read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1 }
  * configure headers = <headers>
  Given path <ruta>
  And params <query>
  And request <cuerpo>
  When method <verbo>
  Then status <status>
  And match response.error == '<error>'

  Examples:
    | caso                                  | headers                   | verbo | ruta                                             | query                           | cuerpo                                                                  | status | error          |
    | visitante crea reserva                | null                      | post  | 'reservas'                                       | null                            | { evento_id: '#(eventoPropio)', tipo: 'General', cantidad: 1 }          | 401    | no_autenticado |
    | visitante paga reserva                | null                      | post  | 'reservas', propia.reserva.id, 'pago'            | null                            | { tarjeta_prueba: '#(ticketpe.cards.approved)' }                        | 401    | no_autenticado |
    | visitante aplica cupón                | null                      | post  | 'reservas', propia.reserva.id, 'cupon'           | null                            | { codigo: 'CUALQUIERA' }                                                | 401    | no_autenticado |
    | visitante lista mis entradas          | null                      | get   | 'mis-entradas'                                   | null                            | null                                                                    | 401    | no_autenticado |
    | visitante ve una entrada              | null                      | get   | 'entradas', propia.entrada.id                    | null                            | null                                                                    | 401    | no_autenticado |
    | visitante transfiere                  | null                      | post  | 'entradas', propia.entrada.id, 'transferir'      | null                            | { correo_destino: '#(dueno.correo)' }                                   | 401    | no_autenticado |
    | visitante pide reembolso              | null                      | post  | 'entradas', propia.entrada.id, 'reembolso'       | null                            | { motivo: 'No podré asistir al evento' }                                | 401    | no_autenticado |
    | visitante hace check-in               | null                      | post  | 'checkin'                                        | null                            | { codigo_qr: '#(propia.entrada.codigo_qr)' }                            | 401    | no_autenticado |
    | visitante pide reporte                | null                      | get   | 'reportes', 'ventas'                             | { evento_id: '#(eventoPropio)' } | null                                                                    | 401    | no_autenticado |
    | asistente hace check-in               | auth.bearer(dueno.token)  | post  | 'checkin'                                        | null                            | { codigo_qr: '#(propia.entrada.codigo_qr)' }                            | 403    | no_autorizado  |
    | asistente pide reporte                | auth.bearer(dueno.token)  | get   | 'reportes', 'ventas'                             | { evento_id: '#(eventoPropio)' } | null                                                                    | 403    | no_autorizado  |
    | organizador transfiere entrada ajena  | auth.bearer(org.token)    | post  | 'entradas', propia.entrada.id, 'transferir'      | null                            | { correo_destino: '#(dueno.correo)' }                                   | 403    | no_autorizado  |
    | organizador pide reembolso ajeno      | auth.bearer(org.token)    | post  | 'entradas', propia.entrada.id, 'reembolso'       | null                            | { motivo: 'No podré asistir al evento' }                                | 403    | no_autorizado  |

@TC-API-11 @REQ-HU-E4.1 @api @p1 @critico @seguridad
Scenario Outline: CP02 - nadie ve la entrada de otra persona: <caso>
  * def propia = callonce read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1, soloEvento: '#(eventoPropio)' }
  * def deOtroEvento = callonce read('helpers/entrada-comprada.feature') { token: '#(dueno.token)', cantidad: 1, excluirEvento: '#(eventoPropio)' }
  # call y no callonce: callonce cachea por el texto de la línea y devolvería al mismo dueño
  * def intruso = call read('helpers/usuario.feature')
  * configure headers = <headers>
  Given path 'entradas', <entrada>
  When method get
  Then status <status>
  And match karate.get('response.error') == <error>

  Examples:
    | caso                   | headers                     | entrada                                 | status | error            |
    | dueño                  | auth.bearer(dueno.token)    | propia.entrada.id                       | 200    | null             |
    | otro asistente         | auth.bearer(intruso.token)  | propia.entrada.id                       | 403    | 'no_autorizado'  |
    | organizador del evento | auth.bearer(org.token)      | propia.entrada.id                       | 200    | null             |
    | organizador ajeno      | auth.bearer(org.token)      | deOtroEvento.entrada.id                 | 403    | 'no_autorizado'  |
    | administrador          | auth.bearer(admin.token)    | propia.entrada.id                       | 200    | null             |
    | sin token              | null                        | propia.entrada.id                       | 401    | 'no_autenticado' |
    | id inexistente         | auth.bearer(admin.token)    | '00000000-0000-0000-0000-000000000000'  | 404    | 'no_encontrado'  |

@TC-API-13 @REQ-HU-E1.2 @api @p1 @critico @seguridad
Scenario Outline: CP03 - registrarse declarando <caso> no escala privilegios
  * def cuerpo = karate.merge({ nombre: 'QA Karate', correo: ticketpe.newEmail(), password: utils.randomPassword() }, <extra>)
  Given path 'auth', 'registro'
  And request cuerpo
  When method post
  Then status 201
  * configure headers = auth.bearer(response.token)

  Given path 'auth', 'me'
  When method get
  Then status 200
  And match response.usuario.rol == 'asistente'

  Given path 'reportes', 'ventas'
  And param evento_id = eventoPropio
  When method get
  Then status 403

  Given path 'checkin'
  And request { codigo_qr: 'QR-CUALQUIERA' }
  When method post
  Then status 403

  Examples:
    | caso                | extra                     |
    | rol administrador   | { rol: 'administrador' }  |
    | es_admin verdadero  | { es_admin: true }        |
