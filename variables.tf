variable "region" {
  default     = "us-east-1"
  description = "AWS region"
}


variable "vpc_name" {
  description = "The name of the VPC."
  default = "vpc-tst"
}

variable "vpc_cidr" {
  description = "CIDR blocks for the VPCs"
  type        = string
  
}

variable "azs" {
  description = "A list of availability zones in the region."
  type        = list(string)  
}

variable "private_subnets" {
  description = "Private subnets for each environment"
  type        = list(string)

}

variable "public_subnets" {
  description = "Public subnets for each environment"
  type        = list(string)

} 

variable "cluster_name" {

}
