#!/bin/sh

###################################################
# Configuration Variables
###################################################
MAILCOW_PATH='/opt/mailcow-dockerized'
SSH_KEY_PATH='/root/.ssh/id_rsa'
BORG_PASSPHRASE_FILE='/root/borg-passphrase'
BORG_REPOSITORY='ssh://user@host/./repository'
###################################################

# Discover the binaries to use for the backup process
DOCKER_BIN=$(which docker)
DOCKER_COMPOSE_BIN=$(which docker-compose)

# Change into the mailcow directory
cd "$MAILCOW_PATH"

# Obtain the passphrase of the borg repository
BACKUP_PASSPHRASE=$(cat "$BORG_PASSPHRASE_FILE")

# Discover the name of the volumes to backup
VOLUME_CRYPT=$("$DOCKER_BIN" inspect --format '{{ range .Mounts }}{{ if eq .Destination "/mail_crypt" }}{{ .Name }}{{ end }}{{ end }}' $("$DOCKER_COMPOSE_BIN" -q dovecot-mailcow))
VOLUME_VMAIL_DIR=$("$DOCKER_BIN" inspect --format '{{ range .Mounts }}{{ if eq .Destination "/var/vmail" }}{{ .Name }}{{ end }}{{ end }}' $("$DOCKER_COMPOSE_BIN" ps -q dovecot-mailcow))
VOLUME_VMAIL_INDEX=$("$DOCKER_BIN" inspect --format '{{ range .Mounts }}{{ if eq .Destination "/var/vmail_index" }}{{ .Name }}{{ end }}{{ end }}' $(ps -q dovecot-mailcow))

print_debug () {
	echo "DOCKER_BIN => $DOCKER_BIN"
	echo "DOCKER_COMPOSE_BIN => $DOCKER_COMPOSE_BIN"
	echo "VOLUME_CRYPT => $VOLUME_CRYPT"
	echo "VOLUME_VMAIL_DIR => $VOLUME_VMAIL_DIR"
	echo "VOLUME_VMAIL_INDEX => $VOLUME_VMAIL_INDEX"
}

run_backup_container () {
	# To perform the backup of the mailcow we need to run a new Docker container that mounts
	# all the relevant volumes as well as the SSH key that shall be used for backing up the
	# contents of those directories to borg. Local repositories are not supported at this point.
	"$DOCKER_BIN" run --rm -i \
	--network host \
	-v "$SSH_KEY_PATH":/ssh/id_rsa:ro \
	-v "$VOLUME_CRYPT":/vmail_crypt:ro \
	-v "$VOLUME_VMAIL_DIR":/vmail:ro \
	-v "$VOLUME_VMAIL_INDEX":/vmail_index:ro \
	-v ~/.cache/borg:/root/.cache/borg \
	-v ~/.config/borg:/root/.config/borg \
	-e BORG_RSH="ssh -i /ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=30 -o TCPKeepAlive=yes" \
	-e BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes \
	-e BORG_PASSPHRASE="$BACKUP_PASSPHRASE" \
        ghcr.io/rescaled/borg:latest \
	create \
	--debug \
	--stats \
	--compression lz4 \
	"$BORG_REPOSITORY"::'{now:%Y-%m-%d_%H:%M:%S}' \
	/vmail_crypt /vmail_index /vmail
}

run_purge_container () {
	# After performing the backup we purge no longer needed backups from the repository to save space.
	"$DOCKER_BIN" run --rm -i \
	--network host \
	-v "$SSH_KEY_PATH":/ssh/id_rsa:ro \
	-v ~/.cache/borg:/root/.cache/borg \
	-v ~/.config/borg:/root/.config/borg \
	-e BORG_RSH="ssh -i /ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=30 -o TCPKeepAlive=yes" \
	-e BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes \
	-e BORG_PASSPHRASE="$BACKUP_PASSPHRASE" \
	ghcr.io/rescaled/borg:latest \
	prune \
	--debug \
	--list \
	--keep-hourly 24 \
	--keep-daily 31 \
	--keep-monthly 12 \
	--keep-yearly 10 \
	"$BORG_REPOSITORY"
}

print_debug
run_backup_container
run_purge_container
