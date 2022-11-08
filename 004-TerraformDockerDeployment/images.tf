resource "docker_image" "hello_world" {
  name         = "hello-world"
  build {
    path = "."
    tag  = ["hello-world:develop"]
    label = {
      author : "devopsdaydayup"
    }
  }
}

