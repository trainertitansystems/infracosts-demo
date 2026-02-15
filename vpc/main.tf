#git is the best
#git can be used anywhere
#india is my countery
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "vpc" {
  name                    = "finops-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "finops-subnet"
  ip_cidr_range = "10.20.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

