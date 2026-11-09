terraform {
  required_version = ">= 1.17.1, < 1.18.0"
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 6.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.4.2" }
    local = { source = "hashicorp/local", version = "~> 2.9.1" }
  }
}
