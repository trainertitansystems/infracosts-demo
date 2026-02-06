variable "project_id" {
  type    = string
  default = "siem-486017"
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "zone" {
  type    = string
  default = "us-east1-b"
}

variable "vm_name" {
  type    = string
  default = "siem-elastic-vm"
}


variable "vpc_name" {
  type    = string
  default = "test-vpc"
}

variable "subnet_name" {
  type    = string
  default = "test-vpc"
}


variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}


variable "ssh_user" {
  type    = string
  default = "analyst"
}



variable "ssh_password" {
  type      = string
  default = "524121@Titans"
  sensitive = true
}

