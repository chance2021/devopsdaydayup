#/bin/sh

# Check if the backup files exist or empty
ls -trl /backup
#CONSUL_BACKUP_FILE=/backup/$(ls /backup|grep consul)
#if [ -f "$VAULT_BACKUP_FILE" ] && [ -f "$CONSUL_BACKUP_FILE" ] && [ ! -s "$VAULT_BACKUP_FILE" ] && [ ! -s "$CONSUL_BACKUP_FILE" ]; then echo "Files $VAULT_BACKUP_FILE and $CONSUL_BACKUP_FILE exist but have size 0" && exit 1; elif [ -f "$VAULT_BACKUP_FILE" ] && [ -f "$CONSUL_BACKUP_FILE" ]; then echo "Files $VAULT_BACKUP_FILE and $CONSUL_BACKUP_FILE exist and have size greater than 0"; else echo "One or both of the files $VAULT_BACKUP_FILE and $CONSUL_BACKUP_FILE do not exist" && exit 2; fi 

VAULT_BACKUP_FILE=/backup/$(ls /backup|grep vault)
if [ -f "$VAULT_BACKUP_FILE" ] && [ -s "$VAULT_BACKUP_FILE" ]  
then 
    echo "$VAULT_BACKUP_FILE exists! Backing up now..." 
else 
    echo "Backup fails! Either the file doesn't exist or it is empty. Please check your script!" && exit 2
fi

# Copy backup files to minio object storage
mc alias set local-minio http://$MINIO_ADDR:9000 $MINIO_USERNAME $MINIO_PASSWORD
mc cp --recursive /backup/* local-minio/$BUCKET_NAME


