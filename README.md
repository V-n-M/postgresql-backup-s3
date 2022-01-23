# postgres-backup-s3

Backup PostgresSQL v14 databases to S3 (supports periodic backups)

## Basic Usage

```sh
$ docker run -e S3_ACCESS_KEY_ID=key -e S3_SECRET_ACCESS_KEY=secret -e S3_BUCKET=my-bucket -e S3_PREFIX=backup -e POSTGRES_DATABASE=dbname -e POSTGRES_USER=user -e POSTGRES_PASSWORD=password -e POSTGRES_HOST=localhost voinik/postgres-backup-s3
```

## Kubernetes Deployment

```
apiVersion: v1
kind: Namespace
metadata:
  name: backup

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: backup
spec:
  selector:
    matchLabels:
      app: postgresql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: voinik/postgresql-backup-s3
        imagePullPolicy: Always
        env:
        - name: POSTGRES_DATABASE
          value: ""
        - name: POSTGRES_HOST
          value: ""
        - name: POSTGRES_PORT
          value: ""
        - name: POSTGRES_PASSWORD
          value: ""
        - name: POSTGRES_USER
          value: ""
        - name: S3_ACCESS_KEY_ID
          value: ""
        - name: S3_SECRET_ACCESS_KEY
          value: ""
        - name: S3_BUCKET
          value: ""
        - name: S3_ENDPOINT
          value: ""
        - name: S3_PREFIX
          value: ""
        - name: SCHEDULE
          value: ""
```

## Environment variables

| Variable             | Default   | Required | Description                                                                                                              |
|----------------------|-----------|----------|--------------------------------------------------------------------------------------------------------------------------|
| POSTGRES_DATABASE    |           | Y        | Database you want to backup or 'all' to backup everything                                                                |
| POSTGRES_HOST        |           | Y        | The PostgreSQL host                                                                                                      |
| POSTGRES_PORT        | 5432      |          | The PostgreSQL port                                                                                                      |
| POSTGRES_USER        |           | Y        | The PostgreSQL user                                                                                                      |
| POSTGRES_PASSWORD    |           | Y        | The PostgreSQL password                                                                                                  |
| POSTGRES_EXTRA_OPTS  |           |          | Extra postgresql options                                                                                                 |
| S3_ACCESS_KEY_ID     |           | Y        | Your AWS access key                                                                                                      |
| S3_SECRET_ACCESS_KEY |           | Y        | Your AWS secret key                                                                                                      |
| S3_BUCKET            |           | Y        | Your AWS S3 bucket path                                                                                                  |
| S3_PREFIX            | backup    |          | Path prefix in your bucket                                                                                               |
| S3_REGION            | us-west-1 |          | The AWS S3 bucket region                                                                                                 |
| S3_ENDPOINT          |           |          | The AWS Endpoint URL, for S3 Compliant APIs such as [minio](https://minio.io)                                            |
| S3_S3V4              | no        |          | Set to `yes` to enable AWS Signature Version 4, required for [minio](https://minio.io) servers                           |
| SCHEDULE             |           |          | Backup schedule time, see explainatons below                                                                             |
| ENCRYPTION_PASSWORD  |           |          | Password to encrypt the backup. Can be decrypted using `gpg --batch --pinentry-mode loopback --passphrase $ENCRYPTION_PASSWORD --output backup.dump --decrypt --cipher-algo AES256 backup.dump.enc` |
| DELETE_OLDER_THAN    |           |          | Delete old backups, see explanation and warning below                                                                    |

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

### Delete Old Backups

You can additionally set the `DELETE_OLDER_THAN` environment variable like `-e DELETE_OLDER_THAN="30 days ago"` to delete old backups.

WARNING: this will delete all files in the S3_PREFIX path, not just those created by this script.

### Encryption

You can additionally set the `ENCRYPTION_PASSWORD` environment variable like `-e ENCRYPTION_PASSWORD="superstrongpassword"` to encrypt the backup. It can be decrypted using `gpg --batch --pinentry-mode loopback --passphrase $ENCRYPTION_PASSWORD --output backup.dump --decrypt --cipher-algo AES256 backup.dump.enc`

### Restoring

There is a restore script which you can use. It takes 2 arguments: 1. the target database to restore, and 2. (optional) which backup file from S3 to use for the restore. If you don't pass a second argument, the script will use the latest file stored in your S3 bucket.

**Beware! This command will DROP the target database if it already exists!**
To avoid bad situations, use a target database name that doesn't exist yet. Test if everything is right and then manually replace the restored db for the existing one.

You can use the restore function through docker-compose like so:
`docker-compose exec <containerId> restore.sh <new database name>`
