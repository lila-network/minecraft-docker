#!/bin/sh
set -eu

: "${MEMORY_MIN:=1G}"
: "${MEMORY_MAX:=2G}"

CONSOLE_PIPE="/tmp/minecraft-console"
SERVER_PID=""
SERVER_STATUS=0
SHUTDOWN_REQUESTED=0

if [ "${EULA:-false}" != "true" ]; then
  echo "Minecraft EULA wurde nicht akzeptiert."
  echo "Starte den Container mit: -e EULA=true"
  exit 1
fi

printf "eula=true\n" > eula.txt

rm -f "$CONSOLE_PIPE"
mkfifo "$CONSOLE_PIPE"

cleanup() {
  # Close the persistent write end before removing the pipe.
  exec 3>&- || true
  rm -f "$CONSOLE_PIPE"
}

shutdown() {
  # A second signal must not enqueue another stop command.
  if [ "$SHUTDOWN_REQUESTED" -eq 1 ]; then
    return 0
  fi

  SHUTDOWN_REQUESTED=1
  echo "Shutdown signal received. Stopping Minecraft server gracefully..."

  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "Sending stop command..."
    printf "stop\n" >&3 || true
  fi
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

# Keep the write side of the pipe open so commands can be sent through FD 3.
exec 3>"$CONSOLE_PIPE"

# A trapped signal interrupts wait(1). The trap only sends the stop command;
# waiting is then resumed here, outside the trap, until Java has terminated.
while kill -0 "$SERVER_PID" 2>/dev/null; do
  if wait "$SERVER_PID"; then
    SERVER_STATUS=0
  else
    SERVER_STATUS=$?
  fi
done

if [ "$SHUTDOWN_REQUESTED" -eq 1 ]; then
  echo "Minecraft server stopped."
fi

exit "$SERVER_STATUS"
