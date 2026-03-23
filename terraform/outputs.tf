output "ip" {
  description = "Public IPv4 address of the VPS"
  value       = hcloud_server.web.ipv4_address
}

output "ipv6" {
  description = "Public IPv6 address of the VPS"
  value       = hcloud_server.web.ipv6_address
}
