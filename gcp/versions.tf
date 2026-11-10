terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.21"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  cloud {
    organization = "successfulsuccess-stashnid"

    workspaces {
      name = "successfulsuccess-gcp"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
