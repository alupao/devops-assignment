terraform {
  backend "s3" {
    key     = "assignment/deployment/terraform.tfstate"
    encrypt = true
  }
}
