sudo apt-get install gnupg curl

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg \
   --dearmor

echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt-get update

sudo apt-get install -y mongodb-org=8.0.1 mongodb-org-database=8.0.1 mongodb-org-server=8.0.1 mongodb-mongosh mongodb-org-mongos=8.0.1 mongodb-org-tools=8.0.1

echo "mongodb-org hold" | sudo dpkg --set-selections
echo "mongodb-org-database hold" | sudo dpkg --set-selections
echo "mongodb-org-server hold" | sudo dpkg --set-selections
echo "mongodb-mongosh hold" | sudo dpkg --set-selections
echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
echo "mongodb-org-tools hold" | sudo dpkg --set-selections

sudo systemctl start mongod

sudo systemctl enable mongod

mkdir scripts
cat <<EOF > ~/scripts/mongo_backup.sh
#!/bin/bash
DIR=$(date "+%d-%m-%y_H%Hm%M")
echo "$DIR"
#Destination to store your mongo backup
DEST=~/db_backup/$DIR
#making dest directory
mkdir $DEST
# If mongodb is protected with username password.
# Set AUTH_ENABLED to 1 
# and add MONGO_USER and MONGO_PASSWD values correctly
AUTH_ENABLED=1
MONGO_HOST='10.0.0.2'
MONGO_PORT='27017'
MONGO_USER='myUserAdmin'
MONGO_PASSWD='abc123'
if [ ${AUTH_ENABLED} -eq 1 ]; then
  AUTH_PARAM=" --username ${MONGO_USER} --password ${MONGO_PASSWD} --authenticationDatabase=admin "
fi
mongodump --host ${MONGO_HOST} --port ${MONGO_PORT} ${AUTH_PARAM} --db=test --out=$DEST
gsutil cp -r $DEST gs://kkap-public-demo-bucket/db-backup/$DIR
EOF

sudo chmod +x ~/scripts/mongo_backup.sh

mongosh << EOF
use admin
db.createUser(
  {
    user: "myUserAdmin",
    pwd:  "abc123",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" },
             { role: "readWriteAnyDatabase", db: "admin"},
             { role: "readWrite", db: "test" }
           ]
  }
)
use test
db.createCollection("user", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ID", "Name", "Email", "Password"],
      properties: {
        ID: {
          bsonType: "objectId",
          description: "must be an objectId and is required"
        },
        Name: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        Email: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        Password: {
          bsonType: "string",
          description: "must be a string and is required"
        }
      }
    }
  }
});
db.createCollection("todos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ID", "Name", "Status", "UserID"],
      properties: {
        ID: {
          bsonType: "objectId",
          description: "must be an objectId and is required"
        },
        Name: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        Status: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        UserID: {
          bsonType: "string",
          description: "must be a string and is required"
        }
      }
    }
  }
});
EOF

# */2 * * * * ~/scripts/mongo_backup.sh # take a backup at every 2nd minute
# * */4 * * * ~/scripts/mongo_backup.sh # take a backup at every minute past every 4th hour


#mongodump --host ${MONGO_HOST} --port ${MONGO_PORT} --db ${DB_NAME} ${AUTH_PARAM} --out ${DB_BACKUP_PATH}
#mongodump --host=10.0.0.2 --port=27017 --db=test --username=myUserAdmin --password=abc123 --authenticationDatabase=admin --out=temp_backup/
#mongodump --host=10.0.0.2 --port=27017 --db=test --username=myUserAdmin --authenticationDatabase=admin --out=/temp_backup/
#mongodump --host=10.0.0.2 --port=27017 --db=test --username=myUserAdmin --password=abc123 --authenticationDatabase=admin --out=gs://kkap-public-demo-bucket/

#gcloud compute scp --zone [ZONE] [USER]@[INSTANCE_NAME]:/path/to/file /dev/stdout | gsutil cp - gs://[BUCKET_NAME]/[FILE_NAME]

#mongoexport --host ${MONGO_HOST} --port ${MONGO_PORT} --db ${DB_NAME} ${AUTH_PARAM} --collection ${Collection_Name} --out ${DB_BACKUP_PATH}/${Collection_Name}.json

#mongodump --host=10.0.0.2 --port=27017 --db=test --out gs://<your_bucket_name>/<your_backup_folder>

#mongodump --uri="mongodb://myUserAdmin:abc123@localhost:27017/admin" --out="gs://kkap-public-demo-bucket/db-backup/"
#db.createUser(
#  {
#    user: "myUserAdmin",
#    pwd:  "abc123",
#    roles: [ { role: "userAdminAnyDatabase", db: "admin" },
#             { role: "readWriteAnyDatabase", db: "admin"},
#           ]
#  }
#)

#db.createUser(
#  {
#    user: "myUser",
#    pwd:  "abc123",
#    roles: [ { role: "readWrite", db: "test" }
#           ]
#  }
#)