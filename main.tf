#Cloud Storage bucket for storing db backups

# Enable the Cloud Storage API
resource "google_project_service" "storage_api" {
  provider = google
  service            = "storage.googleapis.com"
  disable_on_destroy = false
  project = var.gcp_project
}

# Creating a public bucket 
resource "google_storage_bucket" "public_bucket" {
  provider = google
  name          = "kkap-public-open-bucket" # Bucket names must be globally unique
  location      = var.gcp_region
  force_destroy = true # Set to true if you want to allow bucket deletion even if it contains objects

  # Enforce public access (this is where the public part is defined)
  uniform_bucket_level_access = true
}

# Give the bucket public read access.
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.public_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}



# Create a VPC network
resource "google_compute_network" "vpc_network" {
  provider                  = google
  name                      = "kkap-vpc-network"
  auto_create_subnetworks   = false # We will create the subnet manually
  project                   = var.gcp_project
}

# Create a subnet within the VPC
resource "google_compute_subnetwork" "vpc_subnet" {
  provider      = google
  name          = "kkap-vpc-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = var.gcp_region
  network       = google_compute_network.vpc_network.id
  project       = var.gcp_project
}

# Create firewall rules for app to db connect
resource "google_compute_firewall" "app_to_db" {
  provider    = google
  name        = "mongo-connect"
  network     = google_compute_network.vpc_network.id
  description = "Allow traffic from app on gke to db server"
  project     = var.gcp_project
  priority    = 1060
  direction   = "INGRESS"
  #enable_logging = true
  target_tags = ["db-server"]

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Create default firewall rules for the VPC
#resource "google_compute_firewall" "default_allow_internal" {
#  provider    = google
#  name        = "default-allow-internal"
#  network     = google_compute_network.vpc_network.id
#  description = "Allow internal traffic on the VPC"
#  project     = var.gcp_project
#  priority    = 65534
#  direction   = "INGRESS"
#
#  allow {
#    protocol = "icmp"
#  }
#
#  allow {
#    protocol = "tcp"
#    ports    = ["0-65535"]
#  }
#
#  allow {
#    protocol = "udp"
#    ports    = ["0-65535"]
#  }
#
#  source_ranges = ["10.128.0.0/9"]
#}

#resource "google_compute_firewall" "default_allow_ssh" {
#  provider    = google
#  name        = "default-allow-ssh"
#  network     = google_compute_network.vpc_network.id
#  description = "Allow SSH traffic from anywhere"
#  project     = var.gcp_project
#  priority    = 65534
#  direction   = "INGRESS"
#
#  allow {
#    protocol = "tcp"
#    ports    = ["22"]
#  }
#
#  source_ranges = ["0.0.0.0/0"]
#}

resource "google_compute_firewall" "allow_iap_ingress" {
  provider    = google
  name        = "allow-tcp-ingress-from-range"
  network     = google_compute_network.vpc_network.id
  description = "Allow TCP ingress traffic from 35.235.240.0/20 on port 22"
  project     = var.gcp_project
  priority    = 65534
  direction   = "INGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

# Create a NAT gateway
resource "google_compute_router" "router" {
  provider = google
  name     = "kkap-router"
  region   = var.gcp_region
  network  = google_compute_network.vpc_network.id
  project  = var.gcp_project
}

resource "google_compute_router_nat" "nat" {
  provider = google
  name                               = "kkap-nat"
  router                             = google_compute_router.router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.gcp_project
}

# Create a firewall rule to allow egress traffic through the NAT
resource "google_compute_firewall" "allow_egress_nat" {
  provider    = google
  name        = "allow-egress-nat"
  network     = google_compute_network.vpc_network.id
  description = "Allow egress traffic through the NAT"
  project     = var.gcp_project
  priority    = 65534
  direction   = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  source_ranges = ["10.0.0.0/8"]
}



#Compute Engine for hosting the MongoDB server

# Enable the Compute Engine API
resource "google_project_service" "compute_api" {
  provider = google
  service            = "compute.googleapis.com"
  disable_on_destroy = false
  project = var.gcp_project
}



# Create a Compute Engine for MongoDB
resource "google_compute_instance" "mongo_db_server" {
  provider       = google
  name           = "kkap-mongo-db-server"
  machine_type   = "e2-medium" # Choose an appropriate machine type
  project        = var.gcp_project
  zone           = var.gcp_zone
  
  service_account {
    email = data.google_compute_default_service_account.default.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Choose an appropriate image
      size = 10 #gb
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet.id # Use the default network or specify a custom one
    network_ip = google_compute_address.static_internal_ip.address # Use the reserved IP address
  }
  allow_stopping_for_update = true

  metadata_startup_script = local.startup_script_content  # passing startup script file

  # Add network tags here
  tags = ["db-server"] 

}

# Create locals block to hold the startup script.
locals {
  startup_script_path = "startup-script.sh"
  startup_script_content = file(local.startup_script_path)
}

# Reserve a static internal IP address
resource "google_compute_address" "static_internal_ip" {
  provider      = google
  name          = "static-internal-ip-mongodb"
  address_type  = "INTERNAL"
  region        = var.gcp_region
  project       = var.gcp_project
  subnetwork    = google_compute_subnetwork.vpc_subnet.id
  purpose       = "GCE_ENDPOINT"
}

# Output the reserved IP address and the DNS record name for reference
output "mongodb_server_reserved_ip_address" {
  value = google_compute_address.static_internal_ip.address
}

# Fetch the default compute engine service account
data "google_compute_default_service_account" "default" {
  project = var.gcp_project
}

# Assign the Editor role to the default compute engine service account
resource "google_project_iam_member" "editor" {
  project = var.gcp_project
  role    = "roles/editor"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

output "default_compute_engine_service_account" {
  value = data.google_compute_default_service_account.default.email
}



# Artifact registry and vulnerability scanning for storing app-tasky image

# Enable the Artifact Registry API
resource "google_project_service" "artifact_registry_api" {
  provider           = google
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
  project            = var.gcp_project
}

# Enable the Container Scanning API
resource "google_project_service" "container_scanning_api" {
  provider           = google
  service            = "containerscanning.googleapis.com"
  disable_on_destroy = false
  project            = var.gcp_project
}

# Create a Docker repository in Artifact Registry
resource "google_artifact_registry_repository" "docker_repo" {
  provider       = google
  location       = var.gcp_region
  repository_id  = "docker-repo" # Replace with your desired repository ID
  description    = "Docker repository for storing app-tasky image"
  format         = "DOCKER"
  project        = var.gcp_project
}




# GKE Standard Cluster to host Tasky app

# Enable the GKE API
resource "google_project_service" "gke_api" {
  provider = google
  service            = "container.googleapis.com"
  disable_on_destroy = false
  project = var.gcp_project
}

# Create a GKE Standard cluster
resource "google_container_cluster" "gke_cluster" {
  provider = google
  name               = "kkap-terra-st-cluster"
  location           = var.gcp_zone
  project            = var.gcp_project
  deletion_protection = false

  initial_node_count = 1

    node_config {
      machine_type = "e2-medium"
      disk_size_gb = 10
    }

  # Autopilot settings
  # enable_autopilot = true

  # Network configuration
  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.vpc_subnet.id
  
  # Ensure the GKE API is enabled before creating the cluster
  depends_on = [google_project_service.gke_api]
}

# Export the cluster name and endpoint
output "gke_cluster_name" {
  value       = google_container_cluster.gke_cluster.name
  description = "GKE cluster name"
}

output "gke_cluster_endpoint" {
  value       = google_container_cluster.gke_cluster.endpoint
  description = "GKE cluster endpoint"
}

output "gke_cluster_master_version" {
  value = google_container_cluster.gke_cluster.master_version
  description = "GKE cluster master version"
}




# Binary Authorization

# Enable the Binary Authorization API
resource "google_project_service" "binary_authorization_api" {
  provider = google
  service            = "binaryauthorization.googleapis.com"
  disable_on_destroy = false
  project = var.gcp_project
}

# Enable the Cloud Key Management Service (KMS) API
resource "google_project_service" "kms_api" {
  provider = google
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
  project = var.gcp_project
  depends_on = [
    google_project_service.binary_authorization_api
  ]
}

# Create a Key Ring
resource "google_kms_key_ring" "key_ring" {
  provider   = google
  name       = "kkap-key-ring"
  location   = var.gcp_region
  project    = var.gcp_project
  depends_on = [google_project_service.kms_api]
}

# Create a Crypto Key (Signing Key)
resource "google_kms_crypto_key" "signing_key" {
  provider   = google
  name            = "kkap-signing-key"
  key_ring        = google_kms_key_ring.key_ring.id
  purpose         = "ASYMMETRIC_SIGN"
  # rotation_period = "100000s"
  version_template {
    algorithm = "EC_SIGN_P256_SHA256"
    #algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  # protection_level = "HSM"
  }
  depends_on = [google_kms_key_ring.key_ring]
}



# Get the managed DNS zone (assuming it already exists)
#data "google_dns_managed_zone" "managed_zone" {
#  provider = google
#  name     = var.dns_zone_name # Replace with your DNS zone name
#  project = var.gcp_project
#}

# Add a DNS record (A record) to point to the reserved IP
#resource "google_dns_record_set" "a_record" {
#  provider       = google
#  name           = "${var.dns_record_name}.${data.google_dns_managed_zone.managed_zone.dns_name}" # Replace with your desired record name
#  managed_zone = data.google_dns_managed_zone.managed_zone.name
#  type           = "A"
#  ttl            = 300
#  project = var.gcp_project
#  rrdatas        = [google_compute_address.static_ip.address]
#}



#output "dns_record_fqdn" {
#  value = google_dns_record_set.a_record.name
#}
