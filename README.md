# Vulnerable demo

This document outlines the steps to set up and interact with the vulnerable demo environment, including MongoDB configuration and Artifact Registry interactions

## MongoDB-server setup
Execute after the startup-scirpt has run and mongoDB has been installed

### DB Initial User setup
Check if user exists, else create user

1.  **Connect to MongoDB:**
    ```bash
    mongosh
    ```

2.  **Switch to the "admin" database:**
    ```bash
    use admin
    ```

3.  **Create the `myUserAdmin` user:**
    ```bash
    db.createUser({
      user: "myUserAdmin",
      pwd: "abc123",
      roles: [
        { role: "userAdminAnyDatabase", db: "admin" },
        { role: "readWriteAnyDatabase", db: "admin" },
        { role: "readWrite", db: "test" },
      ],
    })
    ```

### DB Collection Creation

1. **Create `user` Collection**:
```bash
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
```
2. **Create `todos` Collection**
```bash
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
```

### DB IP binding change from default localhost to 0.0.0.0
1.  **Verify current binding**
```bash
cat /etc/mongodb.conf
```
2. **Edit "mongodb.conf" to change ipv4 binding**
```bash
sudo nano /etc/mongod.conf
# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
```

### DB Verification 

1.  **Switch to admin:**
    ```bash
    use admin
    ```

2.  **Show Users:**
    ```bash
    show users
    ```

3.  **List Collections:**
    ```bash
    db.getCollectionNames()
    ```


## Artifact Registry (Docker)
Refer to the official Google Cloud documentation for detailed guidance on pushing and pulling Docker images to Artifact Registry:

-   [Pushing and Pulling Docker Images](https://cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling)

### Authentication

1.  **Authenticate Docker with Google Cloud - execute in tasky folder:**
gcloud auth configure-docker \
    Asia-south1-docker.pkg.dev
gcloud auth configure-docker \
    us-west1-docker.pkg.dev

### Image Management - Docker build run push
Execute in "tasky" folder

1. **Determine the Image Name**
```bash
asia-south1-docker.pkg.dev/kkap-vuln-demo/docker-repo/tasky
us-west1-docker.pkg.dev/clgcporg10-161/docker-repo/tasky

```
2. **Building the Image**
```bash
docker build -t asia-south1-docker.pkg.dev/kkap-vuln-demo/docker-repo/tasky:latest .
docker build -t us-west1-docker.pkg.dev/clgcporg10-161/docker-repo/tasky:latest .

```
3. **Test the Image**
```bash
docker run -p 8080:8080 asia-south1-docker.pkg.dev/kkap-vuln-demo/docker-repo/tasky
docker run -p 8080:8080 us-west1-docker.pkg.dev/clgcporg10-161/docker-repo/tasky

```
4. **Push the Image to Artifact Registry**
```bash
docker push asia-south1-docker.pkg.dev/kkap-vuln-demo/docker-repo/tasky:latest
docker push us-west1-docker.pkg.dev/clgcporg10-161/docker-repo/tasky:latest

```

## GKE

### Get unique ID of service account used in cluster
```bash
gcloud iam service-accounts describe 333306257483-compute@developer.gserviceaccount.com
gcloud iam service-accounts describe 815204485712-compute@developer.gserviceaccount.com
```

### Copy unique id and assign service account cluster admin role
```bash
kubectl create clusterrolebinding kkap-terra-st-cluster-sa-admin \
    --clusterrole cluster-admin \
    --user 116397052416636905416
```

## Public Bucket access

1. You can access a public object using the following URI: 
```bash
https://storage.googleapis.com/kkap-public-open-bucket/db-backup/10-03-25_H00m01/test/todos.bson
```

2. You can also list all the objects in a bucket using the following URI: 
```bash
https://console.cloud.google.com/storage/browser/kkap-public-open-bucket
```
## Git

1. initialise local directory as a Git repository. By default, the initial branch is called main. you can set the name of the default branch using -b
```bash
git init
```
2. set user name 
```bash
git config --global user.name kkap-one
```
3. set user email
```bash
git config --global user.email triplek.k@gmail.com
```
4. Add the files in your new local repository. This stages them for the commit.
```bash
git add .
```
5. Commit the files that you've staged in your local repository.
```bash
git commit -m "initial commit"
```
6. Add the URL for the remote repository where your local repository will be pushed
```bash
git remote add origin https://github.com/kkap-one/infra-tasky-wiz.git
```
7. To push the changes in your local repository to GitHub. -f option on git push forces the push
```bash
git push -f origin main
```
8. Ignore large file
```bash
git filter-branch -f --index-filter 'git rm --cached -r --ignore-unmatch .terraform/providers/registry.terraform.io/hashicorp/google/6.23.0/linux_amd64/terraform-provider-google_v6.23.0_x5'
git filter-repo --invert-paths --path .terraform/providers/registry.terraform.io/hashicorp/google/6.23.0/linux_amd64/terraform-provider-google_v6.23.0_x5
```

9. If you try to pull and get "Refusing to merge unrelated histories"; use below
```bash
git pull origin branch_name --allow-unrelated-histories
```

Approx GKE Standard Config:
POST https://container.googleapis.com/v1beta1/projects/kkap-vuln-demo/locations/asia-south1/clusters
{
  "cluster": {
    "name": "cluster-trial-1",
    "masterAuth": {
      "clientCertificateConfig": {}
    },
    "network": "projects/kkap-vuln-demo/global/networks/kkap-vpc-network",
    "addonsConfig": {
      "httpLoadBalancing": {},
      "horizontalPodAutoscaling": {},
      "kubernetesDashboard": {
        "disabled": true
      },
      "dnsCacheConfig": {},
      "gcePersistentDiskCsiDriverConfig": {
        "enabled": true
      },
      "gcsFuseCsiDriverConfig": {},
      "rayOperatorConfig": {}
    },
    "subnetwork": "projects/kkap-vuln-demo/regions/asia-south1/subnetworks/kkap-vpc-subnet",
    "nodePools": [
      {
        "name": "default-pool",
        "config": {
          "machineType": "e2-medium",
          "diskSizeGb": 100,
          "oauthScopes": [
            "https://www.googleapis.com/auth/cloud-platform"
          ],
          "metadata": {
            "disable-legacy-endpoints": "true"
          },
          "imageType": "COS_CONTAINERD",
          "diskType": "pd-balanced",
          "shieldedInstanceConfig": {
            "enableIntegrityMonitoring": true
          },
          "advancedMachineFeatures": {
            "enableNestedVirtualization": false
          },
          "resourceManagerTags": {}
        },
        "initialNodeCount": 1,
        "autoscaling": {},
        "management": {
          "autoUpgrade": true,
          "autoRepair": true
        },
        "networkConfig": {},
        "upgradeSettings": {
          "maxSurge": 1,
          "strategy": "SURGE"
        },
        "queuedProvisioning": {}
      }
    ],
    "networkPolicy": {},
    "ipAllocationPolicy": {
      "useIpAliases": true,
      "stackType": "IPV4"
    },
    "binaryAuthorization": {
      "evaluationMode": "DISABLED"
    },
    "autoscaling": {},
    "networkConfig": {
      "datapathProvider": "LEGACY_DATAPATH",
      "defaultEnablePrivateNodes": false
    },
    "defaultMaxPodsConstraint": {
      "maxPodsPerNode": "8"
    },
    "authenticatorGroupsConfig": {},
    "databaseEncryption": {
      "state": "DECRYPTED"
    },
    "shieldedNodes": {
      "enabled": true
    },
    "releaseChannel": {
      "channel": "REGULAR"
    },
    "notificationConfig": {
      "pubsub": {}
    },
    "initialClusterVersion": "1.31.5-gke.1169000",
    "location": "asia-south1",
    "loggingConfig": {
      "componentConfig": {
        "enableComponents": [
          "SYSTEM_COMPONENTS",
          "WORKLOADS"
        ]
      }
    },
    "monitoringConfig": {
      "componentConfig": {
        "enableComponents": [
          "SYSTEM_COMPONENTS",
          "STORAGE",
          "POD",
          "DEPLOYMENT",
          "STATEFULSET",
          "DAEMONSET",
          "HPA",
          "CADVISOR",
          "KUBELET"
        ]
      },
      "managedPrometheusConfig": {
        "enabled": true,
        "autoMonitoringConfig": {
          "scope": "NONE"
        }
      }
    },
    "nodePoolAutoConfig": {
      "resourceManagerTags": {}
    },
    "securityPostureConfig": {
      "mode": "BASIC",
      "vulnerabilityMode": "VULNERABILITY_ENTERPRISE"
    },
    "controlPlaneEndpointsConfig": {
      "dnsEndpointConfig": {
        "allowExternalTraffic": false
      },
      "ipEndpointsConfig": {
        "enabled": true,
        "enablePublicEndpoint": true,
        "globalAccess": false,
        "authorizedNetworksConfig": {}
      }
    },
    "enterpriseConfig": {
      "desiredTier": "STANDARD"
    },
    "secretManagerConfig": {
      "enabled": false
    }
  }
}



Approx GKE autocluster Config:
POST https://container.googleapis.com/v1/projects/kkap-vuln-demo/locations/asia-south1/clusters
{
  "cluster": {
    "name": "autopilot-cluster-1",
    "network": "projects/kkap-vuln-demo/global/networks/kkap-vpc-network",
    "subnetwork": "projects/kkap-vuln-demo/regions/asia-south1/subnetworks/kkap-vpc-subnet",
    "networkPolicy": {},
    "ipAllocationPolicy": {
      "useIpAliases": true,
      "clusterIpv4CidrBlock": "/17",
      "stackType": "IPV4"
    },
    "binaryAuthorization": {
      "evaluationMode": "DISABLED"
    },
    "autoscaling": {
      "enableNodeAutoprovisioning": true,
      "autoprovisioningNodePoolDefaults": {}
    },
    "networkConfig": {
      "enableIntraNodeVisibility": true,
      "datapathProvider": "ADVANCED_DATAPATH",
      "defaultEnablePrivateNodes": false
    },
    "authenticatorGroupsConfig": {},
    "databaseEncryption": {
      "state": "DECRYPTED"
    },
    "verticalPodAutoscaling": {
      "enabled": true
    },
    "releaseChannel": {
      "channel": "REGULAR"
    },
    "notificationConfig": {
      "pubsub": {}
    },
    "initialClusterVersion": "1.31.5-gke.1169000",
    "location": "asia-south1",
    "autopilot": {
      "enabled": true
    },
    "loggingConfig": {
      "componentConfig": {
        "enableComponents": [
          "SYSTEM_COMPONENTS",
          "WORKLOADS"
        ]
      }
    },
    "monitoringConfig": {
      "componentConfig": {
        "enableComponents": [
          "SYSTEM_COMPONENTS",
          "STORAGE",
          "POD",
          "DEPLOYMENT",
          "STATEFULSET",
          "DAEMONSET",
          "HPA",
          "CADVISOR",
          "KUBELET"
        ]
      },
      "managedPrometheusConfig": {
        "enabled": true,
        "autoMonitoringConfig": {
          "scope": "NONE"
        }
      }
    },
    "nodePoolAutoConfig": {
      "resourceManagerTags": {}
    },
    "securityPostureConfig": {
      "mode": "BASIC",
      "vulnerabilityMode": "VULNERABILITY_DISABLED"
    },
    "controlPlaneEndpointsConfig": {
      "dnsEndpointConfig": {
        "allowExternalTraffic": false
      },
      "ipEndpointsConfig": {
        "enabled": true,
        "enablePublicEndpoint": true,
        "globalAccess": false,
        "authorizedNetworksConfig": {}
      }
    },
    "enterpriseConfig": {
      "desiredTier": "STANDARD"
    },
    "secretManagerConfig": {
      "enabled": false
    }
  }
}