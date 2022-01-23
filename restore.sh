#! /bin/sh

set -e
set -o pipefail

if [ -z "$1" ]; then
    echo "Name of the target db needed in first argument"
	exit 1
fi

TARGET_DB="$1"
echo "TARGET_DB: ${TARGET_DB}"

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD

if [ -z "$2" ]; then
    echo "No S3 target provided. Finding latest backup instead"
    TARGET_BACKUP=$(aws $AWS_ARGS s3 ls s3://$S3_BUCKET/$S3_PREFIX/ | sort | tail -n 1 | awk '{ print $4 }')
else
    TARGET_BACKUP="$2"
fi

echo "TARGET_BACKUP: ${TARGET_BACKUP}"

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
    echo "You need to set the S3_ACCESS_KEY_ID environment variable."
    exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
    echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
    exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
    echo "You need to set the S3_BUCKET environment variable."
    exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ]; then
    echo "You need to set the POSTGRES_DATABASE environment variable."
    exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
    if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
        POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
        POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
    else
        echo "You need to set the POSTGRES_HOST environment variable."
        exit 1
    fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
    echo "You need to set the POSTGRES_USER environment variable."
    exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
    echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
    exit 1
fi

if [ -z "$ENCRYPTION_PASSWORD" ]; then
    echo "You need to set the ENCRYPTION_PASSWORD environment variable so the backup can be decrypted and restored."
    exit 1
fi

if [ "${S3_ENDPOINT}" == "**None**" ]; then
    AWS_ARGS=""
else
    AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi


#POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

echo "Fetching ${TARGET_BACKUP} from S3"
aws $AWS_ARGS s3 cp s3://$S3_BUCKET/$S3_PREFIX/${TARGET_BACKUP} /home/app/backup/backup.dump.enc

echo "Decrypting backup file"
#openssl aes-256-cbc -d -in backup.sql.gz.enc -out backup.sql.gz -k $ENCRYPTION_PASSWORD
gpg --batch --pinentry-mode loopback --passphrase $ENCRYPTION_PASSWORD --output /home/app/backup/backup.dump --decrypt --cipher-algo AES256 /home/app/backup/backup.dump.enc

PG_CONN_PARAMETERS="-h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER}"

echo "Dropping target DB"
PGPASSWORD=${POSTGRES_PASSWORD} dropdb ${PG_CONN_PARAMETERS} --if-exists ${TARGET_DB}

echo "Creating new DB"
PGPASSWORD=${POSTGRES_PASSWORD} createdb ${PG_CONN_PARAMETERS} -O ${POSTGRES_USER} ${TARGET_DB}

echo "Restoring ${TARGET_BACKUP}"
RESTORE_ARGS='-c -j 4'
# Only works if the cluster is different- all the credentials are the same
#psql -f /backups/globals.sql ${TARGET_DB}
PGPASSWORD=${POSTGRES_PASSWORD} pg_restore ${PG_CONN_PARAMETERS} /home/app/backup/backup.dump -d ${TARGET_DB} ${RESTORE_ARGS}

# psql $POSTGRES_HOST_OPTS -d $POSTGRES_DATABASE < backup.sql
echo "Restore complete"

echo "Removing backups"
rm /home/app/backup/backup.dump
rm /home/app/backup/backup.dump.enc