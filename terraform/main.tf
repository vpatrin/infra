terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }

  backend "s3" {
    bucket = "victorpatrin-terraform-state"
    key    = "infra/terraform.tfstate"
    region = "eu-central"

    endpoints = {
      s3 = "https://hel1.your-objectstorage.com"
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

provider "hcloud" {
  # Set via HCLOUD_TOKEN env var
}

data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

resource "hcloud_server" "web" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = var.image

  ssh_keys = [data.hcloud_ssh_key.default.id]

  backups            = var.backups
  delete_protection  = var.delete_protection
  rebuild_protection = var.delete_protection

  labels = {
    role = "web"
    env  = "production"
  }
}

resource "hcloud_firewall" "web" {
  name = var.firewall_name

  dynamic "rule" {
    for_each = var.ingress_ports
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = rule.value
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}

resource "hcloud_firewall_attachment" "web" {
  firewall_id = hcloud_firewall.web.id
  server_ids  = [hcloud_server.web.id]
}
