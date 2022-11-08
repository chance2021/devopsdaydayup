output "docker_container_name" {
  value       = docker_container.hello_world.name
  description = "Docker container name"
  sensitive   = false
}
