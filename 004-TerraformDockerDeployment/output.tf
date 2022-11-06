output "docker_container_name" {
  value       = docker_container.nginx.name
  description = "Docker container name"
  sensitive   = false
}
