# =============================================================================
# Server
# =============================================================================

variable "server_name" {
  description = "Server hostname"
  type        = string
  default     = "web-01"
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "hel1"
}

variable "image" {
  description = "OS image"
  type        = string
  default     = "debian-13"
}

variable "ssh_key_name" {
  description = "Name of the SSH key in Hetzner Cloud (must match exactly)"
  type        = string
  default     = "victor-laptop"
}

# =============================================================================
# Firewall
# =============================================================================

variable "firewall_name" {
  description = "Name of the cloud firewall"
  type        = string
  default     = "web-firewall"
}

variable "ingress_ports" {
  description = "TCP ports to allow inbound"
  type        = list(string)
  default     = ["22", "80", "443"]
}

# =============================================================================
# Protection & backups
# =============================================================================

variable "backups" {
  description = "Enable automated Hetzner backups (~€0.70/month)"
  type        = bool
  default     = true
}

variable "delete_protection" {
  description = "Prevent accidental server deletion and rebuild"
  type        = bool
  default     = true
}
