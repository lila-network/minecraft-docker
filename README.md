# Minecraft Docker

A small, self-contained vanilla Minecraft Java Edition server packaged as an OCI image.

## Getting Started

This image runs a vanilla Minecraft Java Edition server in Docker.

The container runs as the non-root user `10001:10001`. When using a bind-mounted data directory, make sure the directory exists and is owned by this user.

> [!CAUTION]
> Please read [the Security section](#security) carefully before running a Minecraft server that is exposed to the internet!

### 1. Create the data directory

```bash
mkdir -p ./data
sudo chown -R 10001:10001 ./data
chmod 755 ./data
```

The `./data` directory will contain the Minecraft world, server configuration, whitelist, ops list, bans, and other runtime files.

### 2. Create a `docker-compose.yml`

```yaml
services:
  minecraft:
    image: ghcr.io/lila-network/minecraft-docker:26.1
    container_name: minecraft
    restart: unless-stopped

    ports:
      - "25565:25565" # Game Port

    environment:
      EULA: "true"
      MEMORY_MIN: "1G"
      MEMORY_MAX: "4G"

    volumes:
      - ./data:/data

    stop_signal: SIGTERM
    stop_grace_period: 2m
```

### 3. Start the server

```bash
docker compose up -d
```

You can follow the server logs with:

```bash
docker compose logs -f
```

The first startup may take a moment because Minecraft creates the default world and configuration files.

### 4. Stop the server

To stop and remove the running container while keeping your data:

```bash
docker compose down
```

The container handles the shutdown procedure and allows the server to save players, worlds, and chunks before the container exits.

Do not use:

```bash
docker compose down -v
```

or:

```bash
docker compose down --volumes
```

unless you intentionally want to remove Docker volumes.

When using the bind mount shown above, your world data is stored in `./data`.

### 5. Connect to the server

You can connect to the server directly with your Minecraft Java Edition client.

If the server runs on your local machine, use:

```text
localhost:25565
```

If the server runs on another machine, use that machine's IP address:

```text
192.0.2.10:25565
```

If you are using the default Minecraft port `25565`, players can also connect without specifying the port:

```text
192.0.2.10
```

#### Using a domain name

To connect with a domain name, create an `A` record pointing to your server's public IPv4 address.

Example:

| Type | Name | Value |
| --- | --- | --- |
| `A` | `mc` | `192.0.2.10` |

This allows players to connect using:

```text
mc.example.com
```

If your server also has IPv6, you can additionally create an `AAAA` record:

| Type | Name | Value |
| --- | --- | --- |
| `AAAA` | `mc` | `2001:db8::10` |

#### Using an SRV record

Minecraft Java Edition supports DNS `SRV` records. This is useful if your server does not use the default port `25565`, or if you want players to connect through a clean domain without typing the port.

For this example, we assume that all records are created within the `example.com` DNS zone.

First, create an `A` record for the actual server host:

| Type | Name | Value |
| --- | --- | --- |
| `A` | `mc` | `192.0.2.10` |

Then create an `SRV` record for Minecraft:

| Type | Name | Priority | Weight | Port | Target |
| --- | --- | ---: | ---: | ---: | --- |
| `SRV` | `_minecraft._tcp.play` | `0` | `5` | `25565` | `mc.example.com` |

The SRV target should be a hostname, not an IP address. Some DNS providers may require the target to end with a trailing dot, for example `mc.example.com.`.

This allows players to connect using:

```text
play.example.com
```

without entering the port manually.

If your DNS provider asks for the SRV value as a single line, it usually looks like this:

```text
0 5 25565 mc.example.com
```

#### Using a custom public port

The Minecraft server inside the container listens on port `25565` by default. In most Docker setups, you should leave the Minecraft `server-port` setting unchanged and change only the Docker Compose port mapping.

Docker port mappings use this format:

```text
HOST_PORT:CONTAINER_PORT
```

For example, to make the server reachable publicly on port `25566`, map host port `25566` to container port `25565`:

```yaml
ports:
  - "25566:25565"
```

In this example:

- `25566` is the public port players connect to.
- `25565` is the internal port used by the Minecraft server inside the container.

Players can connect using:

```text
example.com:25566
```

You usually do **not** need to change this setting in `./data/server.properties`:

```properties
server-port=25565
```

Changing `server-port` is only needed if you specifically want the Minecraft server process inside the container to listen on a different internal port. For normal Docker setups, changing the Compose port mapping is simpler and less error-prone.

If you use an SRV record with a custom public port, the SRV record should point to the public host port.

Example Compose mapping:

```yaml
ports:
  - "25566:25565"
```

Example SRV record:

| Type | Name | Priority | Weight | Port | Target |
| --- | --- | ---: | ---: | ---: | --- |
| `SRV` | `_minecraft._tcp.play` | `0` | `5` | `25566` | `mc.example.com` |

This allows players to connect using:

```text
play.example.com
```

without typing `:25566`.

## Security

> [!IMPORTANT]
> Minecraft servers can be exposed to the internet by design. However, if you want to do so, take the following security considerations into account.

### Do not expose RCON publicly

RCON allows remote administration of the server. Anyone who can reach the RCON port and knows or guesses the password can execute server commands.

If you do not need RCON, do not publish the RCON port.

⚠️ Avoid this on public servers:

```yaml
ports:
  - "25565:25565"
  - "25575:25575" # ⚠️
```

If you need RCON only from the host machine, bind it to localhost:

```yaml
ports:
  - "25565:25565"
  - "127.0.0.1:25575:25575"
```

This makes RCON available from the Docker host only, not from the public internet.

Then enable RCON in `./data/server.properties`:

```properties
enable-rcon=true
rcon.port=25575
rcon.password=change-this-to-a-long-random-password
```

Use a long, random password. Do not reuse passwords from other services.

### Use a firewall

Only expose the ports that are actually required.

For a normal public Minecraft server, usually only this port needs to be reachable from the internet:

```text
25565/tcp
```

If you publish Minecraft on a custom public port, allow that host port instead. For example, if you use `25566:25565`, allow:

```text
25566/tcp
```

RCON should usually be restricted to localhost, a private network, or a VPN.

Example UFW rules for the default Minecraft port:

```bash
sudo ufw allow 25565/tcp
sudo ufw deny 25575/tcp # RCON port
```

If you manage the server remotely, make sure you do not lock yourself out of SSH.

### Keep online mode enabled

For public servers, keep `online-mode` enabled in `server.properties`:

```properties
online-mode=true
```

This ensures that players authenticate with Mojang/Microsoft accounts. Disabling online mode makes impersonation much easier and should only be used for special private setups where you fully understand the risks.

### Use a whitelist for private servers

For private servers, enable the whitelist:

```properties
white-list=true
```

Then add players from the server console:

```text
whitelist add PlayerName
```

Or with RCON, if you use it securely:

```text
whitelist add PlayerName
```

### Limit operator permissions

Only give operator permissions to trusted users.

Add operators carefully:

```text
op PlayerName
```

Remove operators when they no longer need admin access:

```text
deop PlayerName
```

You can also configure the default operator permission level in `server.properties`:

```properties
op-permission-level=3
```

Avoid giving unnecessary administrative access.

### Back up your data directory

All important runtime data is stored in `./data`.

Back up this directory regularly:

```text
./data/world/
./data/world_nether/
./data/world_the_end/
./data/server.properties
./data/ops.json
./data/whitelist.json
./data/banned-players.json
./data/banned-ips.json
```

Stop the server before taking file-level backups, or use a backup method that can handle active files safely.

A simple manual backup flow is:

```bash
docker compose down
tar -czf minecraft-backup-$(date +%Y-%m-%d).tar.gz ./data
docker compose up -d
```

### Keep the image updated

> [!IMPORTANT]
> Make sure to back up the `./data` directory before doing potentially destructive actions like upgrading.

To upgrade, follow these steps:

1. Back up the `./data` directory.
2. Make sure the backup completed successfully.
3. Change the image tag in `docker-compose.yml`, for example:

   ```yaml
   image: ghcr.io/lila-network/minecraft-docker:26.1
   ```

   to:

   ```yaml
   image: ghcr.io/lila-network/minecraft-docker:26.1.2
   ```

4. Pull the new image:

   ```bash
   docker compose pull
   ```

5. Start the Minecraft server with the new image:

   ```bash
   docker compose up -d
   ```

### Keep the container non-root

This image runs as user `10001:10001`. When using a bind mount, make sure the data directory is writable by that user:

```bash
mkdir -p ./data
sudo chown -R 10001:10001 ./data
chmod 755 ./data
```

Do not run the container as root unless you have a specific reason.

### Use a graceful shutdown period

Minecraft needs time to save worlds and chunks during shutdown.

Use a Compose grace period:

```yaml
stop_signal: SIGTERM
stop_grace_period: 2m
```

For larger worlds or slower storage, consider increasing this value:

```yaml
stop_grace_period: 5m
```

Avoid force-killing the container unless absolutely necessary.

### Avoid deleting your world by accident

Do not use this unless you intentionally want to remove Docker volumes:

```bash
docker compose down -v
```

or:

```bash
docker compose down --volumes
```

When using the bind mount shown in this README, your world is stored in `./data`. Still, always double-check commands before deleting containers, volumes, or directories.

## Configuration

Minecraft configuration files are stored in the mounted data directory:

```text
./data/server.properties
./data/ops.json
./data/whitelist.json
./data/banned-players.json
./data/banned-ips.json
./data/world/
```

After editing configuration files, restart the container:

```bash
docker compose restart
```

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `EULA` | `false` | Setting `EULA=true` means you accept the Minecraft EULA. Do not set this unless you have read it and agree to it. |
| `MEMORY_MIN` | `1G` | Initial JVM heap size. |
| `MEMORY_MAX` | `2G` | Maximum JVM heap size. |
| `JAVA_OPTS` | empty | Additional Java options passed to the server process. |

## Notes

This image does not include a preconfigured world. All runtime data is stored in `/data`.

Make sure the mounted data directory is writable by user `10001:10001`. Otherwise, the server may fail to create or update world files.

For most setups, the following is enough:

```bash
mkdir -p ./data
sudo chown -R 10001:10001 ./data
chmod 755 ./data
docker compose up -d
```
