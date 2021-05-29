# mailcow-backup-borg
Perform deduplicated backups of your e-mails from your dockerized mailcow installation

## Why?
While [mailcow](https://mailcow.email) offers a backup helper-script out of the box, this script just creates an archive file including everything that was in-scope for that backup. During longer retention periods this causes a huge waste of storage. The solution for this issue is **deduplication**. Files (or more specific: blocks) that already have been part of an older backup are just getting referenced instead of being stored mulitple times. A widely used and battle-proven piece of software that supports deduplicated backups (alongside with a strong encryption) is [borgbackup](https://www.borgbackup.org/).

## Challenges
mailcow runs within Docker containers. The data (e.g. the `vmail` directory) is stored within multiple Docker volumes. Therefore we can't just run `borgbackup` on the local system where the mailcow is installed at. Instead, we need to run a new Docker container for each backup that mounts the target volumes to the container's filesystem and perform a backup of all relevant data within this container. During the backup we need to make sure that not only the `vmail` volume itself is part of the backup, but also the keypair that is used for e-mail encryption. If this keypair wouldn't be part of the backup and lost during a loss of data, the backup would be worthless and all e-mails would be permanently unreadable.
