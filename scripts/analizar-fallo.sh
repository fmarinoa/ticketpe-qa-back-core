#!/usr/bin/env bash
# Diagnostica con IA (Copilot CLI) por que fallo la suite Karate.
# Uso: scripts/analizar-fallo.sh [dir-reportes]   (default: target/karate-reports)
# CI: requiere GITHUB_TOKEN y permiso copilot-requests: write
set -euo pipefail

DIR=${1:-target/karate-reports}
EVIDENCIA=$(mktemp)
trap 'rm -f "$EVIDENCIA"' EXIT

[ -d "$DIR" ] || { echo "No hay reportes en $DIR (la suite no llego a ejecutar)"; exit 0; }

{
  echo "# Evidencia de fallo"
  echo "- commit: $(git rev-parse --short HEAD 2>/dev/null || echo n/a) | rama: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a)"
  [ -n "${GITHUB_RUN_ID:-}" ] && echo "- run: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  echo
  if [ -f "$DIR/karate-summary-json.txt" ]; then
    jq -r '"ambiente: \(.env // "n/a") | escenarios fallidos: \(.scenariosfailed) | pasados: \(.scenariosPassed)"' "$DIR/karate-summary-json.txt"
    echo
  fi
  for f in "$DIR"/*.karate-json.txt; do
    [ -e "$f" ] || continue
    jq -r '
      .relativePath as $feat
      | .scenarioResults[] | select(.failed)
      | "## \($feat):\(.line) — \(.name)  [\([.tags[]? | if type=="object" then .name else . end] | join(","))]",
        ( .stepResults[] | select(.result.status != "passed")
          | "- paso: \(.step.prefix) \(.step.text) → \(.result.status)",
            ((.result.errorMessage // "") | .[0:1500]),
            "```", ((.stepLog // "") | .[-2500:]), "```"
        )
    ' "$f"
  done
} > "$EVIDENCIA"

grep -q '^## ' "$EVIDENCIA" || { echo "Sin escenarios fallidos en $DIR"; exit 0; }

PROMPT="Eres QA automation lead. Analiza esta evidencia de una corrida Karate fallida del repo actual.
Puedes leer los .feature en src/test/java para entender el caso.
Responde en espanol, markdown, maximo 400 palabras, por cada escenario fallido:
1) causa raiz probable (cita el status/body/assert que lo prueba)
2) clasificacion: BUG_API | BUG_TEST | DATA | AMBIENTE | FLAKY
3) accion concreta (archivo/linea si aplica)
Cierra con un veredicto de una linea: bloquea el merge o no.

$(cat "$EVIDENCIA")"

if ! command -v copilot >/dev/null; then
  echo "copilot CLI no instalado (npm i -g @github/copilot). Evidencia cruda:" >&2
  cat "$EVIDENCIA"
  exit 0
fi

INFORME=$(copilot -p "$PROMPT" -s \
  --allow-tool='shell(cat:*)' --allow-tool='shell(ls:*)' --allow-tool='shell(grep:*)')

echo "$INFORME"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && { echo "## Analisis IA del fallo"; echo "$INFORME"; } >> "$GITHUB_STEP_SUMMARY"
exit 0
