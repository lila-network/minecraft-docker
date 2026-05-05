#!/bin/sh
set -eu

: "${MEMORY_MIN:=1G}"
: "${MEMORY_MAX:=2G}"
: "${SAVE_ON_STOP:=true}"
: "${SAVE_DELAY:=5}"

CONSOLE_PIPE="/tmp/minecraft-console"
SERVER_PID=""

if [ "${EULA:-false}" != "true" ]; then
  echo "Minecraft EULA wurde nicht akzeptiert."
  echo "Starte den Container mit: -e EULA=true"
  exit 1
fi

printf "eula=true\n" > eula.txt

rm -f "$CONSOLE_PIPE"
mkfifo "$CONSOLE_PIPE"

cleanup() {
  rm -f "$CONSOLE_PIPE"
}

shutdown() {
  echo "Shutdown signal received. Stopping Minecraft server gracefully..."

  trap - TERM INT

  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    if [ "$SAVE_ON_STOP" = "true" ]; then
      echo "Running save-all flush..."
      printf "save-all flush\n" >&3 || true
      echo "Waiting $SAVE_DELAY for shutdown..."
      sleep "$SAVE_DELAY"
    fi

    echo "Sending stop command..."
    printf "stop\n" >&3 || true

    wait "$SERVER_PID" || true
  fi

  echo "Minecraft server stopped."
  exit 0
}

trap cleanup EXIT
trap shutdown TERM INT

java \
  -Xms"$MEMORY_MIN" \
  -Xmx"$MEMORY_MAX" \
  ${JAVA_OPTS:-} \
  -jar /opt/minecraft/server.jar \
  nogui < "$CONSOLE_PIPE" &

SERVER_PID="$!"

# Keep the write side of the pipe open so we can send commands later.
exec 3>"$CONSOLE_PIPE"

wait "$SERVER_PID"