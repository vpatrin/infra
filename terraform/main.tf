# =============================================================================
# Backend & providers
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.54"
    }
  }

  # State in Hetzner Object Storage (S3-compatible)
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
  # Authenticated via HCLOUD_TOKEN env var (project-scoped)
  # Also used for DNS (Hetzner Cloud Console DNS)
}

# =============================================================================
# Firewall — inbound TCP only, all outbound allowed (default)
# =============================================================================

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

  apply_to {
    label_selector = "role=web"
  }
}

# =============================================================================
# DNS — Hetzner Cloud Console DNS (zones + RRSets for all managed domains)
# =============================================================================

resource "hcloud_zone" "zones" {
  for_each = var.dns_zones
  name     = each.key
  mode     = "primary"
}

resource "hcloud_zone_rrset" "records" {
  for_each = {
    for entry in local.dns_rrsets_flat : "${entry.zone}/${entry.name}/${entry.type}" => entry
  }

  zone    = hcloud_zone.zones[each.value.zone].name
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

locals {
  dns_rrsets_flat = flatten([
    for zone, config in var.dns_zones : [
      for rrset in config.rrsets : {
        zone = zone
        name = rrset.name
        type = rrset.type
        ttl  = rrset.ttl
        records = [
          for ip in(rrset.values != null ? rrset.values : [var.vps_ip]) : { value = ip }
        ]
      }
    ]
  ])
}
