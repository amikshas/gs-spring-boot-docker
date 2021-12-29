output "private-key" {
  value = tls_private_key.private-key.private_key_pem
  sensitive = true
}

output "public-key-openssh" {
  value = tls_private_key.private-key.public_key_openssh
}

output "Node-0" {
  value = aws_instance.kubecluster.*.public_ip[0]
}

output "Node-1" {
  value = aws_instance.kubecluster.*.public_ip[1]
}

output "Node-2" {
  value = aws_instance.kubecluster.*.public_ip[2]
}
