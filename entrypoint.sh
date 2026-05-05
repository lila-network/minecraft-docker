#!/bin/sh
set -eu

: "${MEMORY_MIN:=1G}"
: "${MEMORY_MAX:=2G}"

if [ "${EULA:-false}" != "true" ]; then
  echo "Minecraft EULA wurde nicht akzeptiert."
  echo "Starte den Container mit: -e EULA=true"
  exit 1
fi

printf "eula=true\n" > eula.txt

exec java \
  -Xms"$MEMORY_MIN" \
  -Xmx"$MEMORY_MAX" \
  ${JAVA_OPTS:-} \
  -jar /opt/minecraft/server.jar \
  nogui