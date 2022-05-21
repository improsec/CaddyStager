output "CobaltStrike" {
  value = azurerm_public_ip.Cobalt-PUBLICIP.ip_address
}

output "Caddy" {
  value = azurerm_public_ip.CADDY-PUBLICIP.ip_address
}

output "keys" {
  value = tls_private_key.CSCADDY_ssh.private_key_pem
  sensitive   = true
}

output "CobaltPassword" {
  value = random_password.CobaltAdminPassword.result
  sensitive   = true
}

output "CaddyPassword" {
  value = random_password.CaddyAdminPassword.result
  sensitive   = true
}