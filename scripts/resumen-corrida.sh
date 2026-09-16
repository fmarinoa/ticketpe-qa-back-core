#!/usr/bin/env bash
# Resumen de una corrida para el Job Summary: veredicto, casos en rojo por
# severidad y trazabilidad (ESC / riesgo / severidad / requisito) desde los tags
# de la matriz de diseño (@TC-API-*, @ESC*, @critico.., @p1.., @RIESGO-*, @REQ-*).
# La unidad es el caso (@TC-API-*): los ejemplos de un Outline cuentan como uno.
# Uso: scripts/resumen-corrida.sh [dir-reportes]   (default: target/karate-reports)
set -euo pipefail

DIR=${1:-target/karate-reports}
shopt -s nullglob
REPORTES=("$DIR"/*.karate-json.txt)
[ ${#REPORTES[@]} -gt 0 ] || { echo "No hay reportes en $DIR (la suite no llego a ejecutar)"; exit 0; }

jq -rs '
  def tags: [ .tags[]? | (if type == "object" then .name else . end) | sub("^@"; "") ];
  def tag($re): first(.tags[] | select(test($re))) // "—";
  def rango: {critico: 0, alto: 1, medio: 2, bajo: 3}[sub("^RIESGO-"; "") | ascii_downcase] // 9;
  def celda: gsub("\\|"; "\\|") | gsub("\n"; " ");
  def estado($f): if $f == 0 then "verde" else "ROJO" end;
  def tabla($casos; $campo; $titulo):
    "| \($titulo) | Casos | Rojos | Estado |",
    "|---|---|---|---|",
    ( $casos | map(select(.[$campo] != "—")) | group_by(.[$campo])
      | sort_by(.[0][$campo] | rango)[]
      | (map(select(.falla)) | length) as $f
      | "| \(.[0][$campo]) | \(length) | \($f) | \(estado($f)) |" );

  [ .[] | .relativePath as $feat | .scenarioResults[]?
    | tags as $t
    | { falla: (.failed == true), nombre: .name, ubicacion: "\($feat):\(.line)", tags: $t,
        error: ((.error // "\n") | split("\n")
                | if .[0] | startswith("match failed") then "\(.[0]): \(.[1] // "" | sub("^\\s+"; ""))"
                  else .[0] | sub(", response time.*"; "") end) }
    | . + { caso: tag("^TC-API-"), esc: tag("^ESC[0-9]+$"), sev: tag("^(critico|alto|medio|bajo)$"),
            prio: tag("^p[0-9]$"), riesgo: tag("^RIESGO-"), req: tag("^REQ-") }
    | .caso = (if .caso == "—" then .ubicacion else .caso end)
  ] as $esc
  | [ $esc | group_by(.caso)[]
      | (map(select(.falla))) as $r
      | .[0] + { falla: ($r | length > 0), rojos: ($r | length), total: length,
                 primero: ($r[0] // .[0]) } ] as $casos
  | ($casos | map(select(.falla)) | sort_by((.sev | rango), .caso)) as $rojos
  | ($rojos | map(select(.sev == "critico" and .prio == "p1")) | length) as $bloqueantes

  | "## Resultado", "",
    "**\(if ($rojos | length) == 0 then "VERDE" else "ROJO" end)** · \($casos | map(select(.caso | startswith("TC-API-"))) | length) casos de la matriz · \($rojos | length) en rojo · \($bloqueantes) P1 críticos en rojo · \($esc | length) escenarios ejecutados", "",

    ( if ($rojos | length) == 0 then empty else
        ( "### Casos en rojo", "",
          "| Caso | ESC | Severidad | Prioridad | Ejemplos en rojo | Escenario | Primer fallo |",
          "|---|---|---|---|---|---|---|",
          ( $rojos[] | "| \(.caso) | \(.esc) | \(.sev) | \(.prio) | \(.rojos)/\(.total) | \(.primero.nombre | celda)<br>`\(.primero.ubicacion)` | \(.primero.error | celda) |" ),
          "" )
      end ),

    "### Por severidad", "", tabla($casos; "sev"; "Severidad"), "",
    "### Por escenario de la matriz", "", tabla($casos; "esc"; "ESC"), "",
    "### Por riesgo", "", tabla($casos; "riesgo"; "Riesgo"), "",
    "### Por requisito", "", tabla($casos; "req"; "Requisito")
' "${REPORTES[@]}"
