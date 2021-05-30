# mailcow-backup-borg
Perform deduplicated backups of your e-mails from your dockerized mailcow installation

## Why?
While [mailcow](https://mailcow.email) offers a backup helper-script out of the box, this script just creates an archive file including everything that was in-scope for that backup. During longer retention periods this causes a huge waste of storage. The solution for this issue is **deduplication**. Files (or more specific: blocks) that already have been part of an older backup are just getting referenced instead of being stored mulitple times. A widely used and battle-proven piece of software that supports deduplicated backups (alongside with a strong encryption) is [borgbackup](https://www.borgbackup.org/).

## Challenges
mailcow runs within Docker containers. The data (e.g. the `vmail` directory) is stored within multiple Docker volumes. Therefore we can't just run `borgbackup` on the local system where the mailcow is installed at. Instead, we need to run a new Docker container for each backup that mounts the target volumes to the container's filesystem and perform a backup of all relevant data within this container. During the backup we need to make sure that not only the `vmail` volume itself is part of the backup, but also the keypair that is used for e-mail encryption. If this keypair wouldn't be part of the backup and lost during a loss of data, the backup would be worthless and all e-mails would be permanently unreadable.

## Instructions
First of all you need to download the script or pull this repository and save it on your mailcow host.

    mkdir /opt/mailcow-backup && wget -O /opt/mailcow-backup/run-backup.sh https://raw.githubusercontent.com/rescaled/mailcow-backup-borg/main/run-backup.sh

Open the file with an editor of your choice and set the upper variables to match your environment:

* Set `MAILCOW_PATH` to the base directory of your mailcow installation (where the `docker-compose.yml` is located at)
* Set `SSH_KEY_PATH` to the SSH key you want to use to connect to your remote repository
* Set `BORG_PASSPHRASE_FILE` to the file that contains the passphrase of your remote borg repository
* Set `BORG_REPOSITORY` to the remote borg repository you want to perform your backups to (e.g. `ssh://user@host[:port]/./repository-name`) 

Finally you may want to set different pruning rules for your specific use case. Just scroll down to the `run_purge_container` function and adjust the values of the `--keep-(hourly|daily|weekly|yearly)` parameters. See [the borg documentation](https://borgbackup.readthedocs.io/en/stable/usage/prune.html) on how `borg prune` works in detail.

## Assumptions
This script was made with our specific requirements in mind. It has been released as open source to allow others to profit from the work we've done. However, this implicits that the script does just work under some specific assumptions, yet. Feel free to extend the code to work aside from the following restrictions and assumptions and submit a pull request. Alternatively you can pull this repository and adjust the (not so complicated) bash script to your own needs. This should be easily doable without too much work.

The mailcow backup script utilizing borg for deduplicated backups is only able to work out of the box for the following environment: 

* You run your backups as root
* You run your backups against a (already initialized) remote borg repository via SSH with keybased authentication
* Your remote borg repository is encrypted either with `repokey` or `repokey-blake2`
* Your remote borg repository's passphrase is stored within a file on your mailcow host
* Your mailcow host has direct internet access to download the Docker image from a public registry
* You run hourly backups and keep 24 hourly, 31 daily, 12 monthly and 10 yearly backups 

Of course everything of this can be adjusted, this is just how it is set out of the box. If all of the points above are matching your current environment you can just update the repository URL within the script and you are ready to go.

## Features
* Backup of mailcow's `vmail`, `vmail-index` and `vmail-crypt` volumes
* Auto-detection of the volume names (via `docker inspect`)
* Auto-detection of `docker` and `docker-compose` binaries

## Security
If you discover any security-related issues, please email security@rescaled.de instead of using the issue tracker.

## Credits
- [Tobias Hannaske](https://github.com/thannaske)
- [All Contributors](../../contributors)

## License
The MIT License (MIT). Please see [License File](LICENSE.md) for more information.
