output "ip" {
  description = "Public IPv4 address of the VPS"
  value       = hcloud_server.web.ipv4_address
}
