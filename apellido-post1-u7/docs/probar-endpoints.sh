#!/usr/bin/env bash
# Recorre los checkpoints del enunciado contra la API en marcha y, entre paso y paso, se detiene
# para que puedas tomar la captura (el nombre de archivo sugerido aparece en cada paso).
#
# Uso (con la aplicación ya arrancada en otra terminal; en Windows, desde Git Bash):
#   ./docs/probar-endpoints.sh parte1      -> capturas 01 a 05
#   ./docs/probar-endpoints.sh pagosudes   -> capturas 06 y 08 (arrancar con el perfil "simulador")
#   ./docs/probar-endpoints.sh wompi       -> captura 07 (arrancar con simulador y proveedor=wompi)
#
# La captura 09 (BUILD SUCCESS) sale de ejecutar "mvn clean package" dentro de multas-biblioteca-api/.

BASE="${BASE_URL:-http://localhost:8080}"
SUF="$(date +%H%M%S)"        # sufijo para no chocar con multas de ejecuciones anteriores
LAST_BODY=""
LAST_CODE=""

# req METODO URL [JSON]: muestra el comando, ejecuta curl y deja cuerpo y código en LAST_BODY / LAST_CODE
req() {
  local metodo="$1" url="$2" datos="$3" out
  if [ -n "$datos" ]; then
    echo "\$ curl -X $metodo $url -H 'Content-Type: application/json' -d '$datos'"
    out="$(curl -s -w $'\n%{http_code}' -X "$metodo" "$url" -H 'Content-Type: application/json' -d "$datos")"
  else
    echo "\$ curl -X $metodo $url"
    out="$(curl -s -w $'\n%{http_code}' -X "$metodo" "$url")"
  fi
  LAST_CODE="${out##*$'\n'}"
  LAST_BODY="${out%$'\n'*}"
  echo "$LAST_BODY"
  echo "=> HTTP $LAST_CODE"
  echo
}

id_de() { printf '%s' "$LAST_BODY" | sed -n 's/.*"id" *: *\([0-9][0-9]*\).*/\1/p'; }

json() { printf '{"estudianteId":"%s","concepto":"Libro devuelto tarde","diasAtraso":%s}' "$1" "$2"; }

paso() {
  echo
  echo "=================================================================="
  echo " $1   -> guarda la captura como docs/$2"
  echo "=================================================================="
}

pausa() { read -r -p "[Toma la captura y presiona Enter para continuar] " _; }

if ! curl -s -o /dev/null "$BASE/api/multas"; then
  echo "No hay respuesta en $BASE. Arranca primero la aplicación (mvn spring-boot:run)." >&2
  exit 1
fi

parte1() {
  paso "01 - Generar multa (201, monto calculado)" "01-post-201.png"
  req POST "$BASE/api/multas" "$(json "E$SUF" 5)"
  pausa

  paso "02 - Validación (400)" "02-post-400.png"
  req POST "$BASE/api/multas" '{"estudianteId":"","concepto":"","diasAtraso":0}'
  pausa

  paso "03 - Cuarta multa pendiente (409)" "03-post-409.png"
  for d in 1 2 3; do req POST "$BASE/api/multas" "$(json "L$SUF" "$d")"; done
  req POST "$BASE/api/multas" "$(json "L$SUF" 4)"
  pausa

  paso "04 - Multa inexistente (404)" "04-get-404.png"
  req GET "$BASE/api/multas/999999"
  pausa

  paso "05 - Pago en ventanilla y repetición (409)" "05-pagar-ventanilla.png"
  req POST "$BASE/api/multas" "$(json "V$SUF" 2)"
  local id; id="$(id_de)"
  req PATCH "$BASE/api/multas/$id/pagar"
  req PATCH "$BASE/api/multas/$id/pagar"
  pausa
}

pagosudes() {
  paso "06 - Pago en línea con PagosUDES (200)" "06-pagar-en-linea-pagosudes.png"
  req POST "$BASE/api/multas" "$(json "P$SUF" 5)"
  local id; id="$(id_de)"
  req POST "$BASE/api/multas/$id/pagar-en-linea"
  pausa

  paso "08 - Pago rechazado (402): 30 días = \$15.000 > \$10.000 del simulador" "08-pago-rechazado-402.png"
  req POST "$BASE/api/multas" "$(json "R$SUF" 30)"
  id="$(id_de)"
  req POST "$BASE/api/multas/$id/pagar-en-linea"
  pausa
}

wompi() {
  paso "07 - Pago en línea con Wompi (200, metodoPago WOMPI)" "07-pagar-en-linea-wompi.png"
  req POST "$BASE/api/multas" "$(json "W$SUF" 5)"
  local id; id="$(id_de)"
  req POST "$BASE/api/multas/$id/pagar-en-linea"
  pausa
}

case "$1" in
  parte1)    parte1 ;;
  pagosudes) pagosudes ;;
  wompi)     wompi ;;
  *) echo "Uso: $0 {parte1|pagosudes|wompi}"; exit 1 ;;
esac
