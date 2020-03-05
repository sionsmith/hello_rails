# Most of these are used by kitchen so it can forward them to inspec
output "main_vpc_id" {
  value       = module.k8s_vpc.vpc_id
  description = "ID of the main VPC geenrated by the module"
}
