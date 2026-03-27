# =============================================================================
# VPS IP (used as default for DNS A records)
# =============================================================================

variable "vps_ip" {
  description = "IPv4 address of the production VPS (set via .tfvars or -var)"
  type        = string
}

# =============================================================================
# Firewall
# =============================================================================

variable "firewall_name" {
  description = "Name of the cloud firewall"
  type        = string
  default     = "allow-ssh-http-https"
}

variable "ingress_ports" {
  description = "TCP ports to allow inbound"
  type        = list(string)
  default     = ["22", "80", "443"]
}

# =============================================================================
# DNS
# =============================================================================

variable "dns_zones" {
  description = "DNS zones and their RRSets (values = null uses vps_ip)"
  type = map(object({
    rrsets = list(object({
      name   = string
      type   = string
      values = optional(list(string))
      ttl    = number
    }))
  }))
  default = {
    "victorpatrin.dev" = {
      rrsets = [
        { name = "@", type = "A", values = null, ttl = 600 },
        { name = "*", type = "A", values = null, ttl = 600 },
      ]
    }
    "coupette.club" = {
      rrsets = [
        { name = "@", type = "A", values = null, ttl = 600 },
        { name = "*", type = "A", values = null, ttl = 600 },
      ]
    }
  }
}
