output "vm_public_ip" {
  value = google_compute_instance.siem_vm.network_interface[0].access_config[0].nat_ip
}
