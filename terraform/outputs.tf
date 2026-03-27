output "nameservers" {
  description = "Hetzner DNS nameservers (set these at your registrar)"
  value       = { for zone, z in hcloud_zone.zones : zone => z.authoritative_nameservers.assigned }
}

output "firewall_id" {
  description = "Cloud firewall ID (for reference)"
  value       = hcloud_firewall.web.id
}
