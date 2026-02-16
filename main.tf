#ajflajfdlajlf
#install
terraform {
  required_version = ">= 1.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
provider "google" {
  project = "siem-486017"
  region  = "us-east1"
  zone    = "us-east1-b"
}


########################################
# STARTUP SCRIPT
########################################
locals {
  startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Enable password SSH
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart sshd

    useradd -m -s /bin/bash ${var.ssh_user}
    echo "${var.ssh_user}:${var.ssh_password}" | chpasswd
    usermod -aG sudo ${var.ssh_user}

    apt-get update -y
    apt-get install -y curl gnupg apt-transport-https openjdk-17-jdk

    curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
      | gpg --dearmor -o /usr/share/keyrings/elastic.gpg

    echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
      > /etc/apt/sources.list.d/elastic-8.x.list

    apt-get update -y
    apt-get install -y elasticsearch kibana filebeat

    cat <<EOT > /etc/elasticsearch/elasticsearch.yml
    cluster.name: siem-cluster
    node.name: node-1
    network.host: 0.0.0.0
    http.port: 9200
    discovery.type: single-node
    xpack.security.enabled: false
    EOT

    cat <<EOT > /etc/kibana/kibana.yml
    server.host: "0.0.0.0"
    server.port: 5601
    elasticsearch.hosts: ["http://localhost:9200"]
    EOT

    cat <<EOT > /etc/filebeat/filebeat.yml
    filebeat.inputs:
      - type: filestream
        enabled: true
        paths:
          - /var/log/auth.log

    output.elasticsearch:
      hosts: ["http://localhost:9200"]

    setup.kibana:
      host: "http://localhost:5601"
    EOT

    chmod 600 /etc/filebeat/filebeat.yml

    systemctl daemon-reexec
    systemctl enable elasticsearch kibana filebeat

    systemctl start elasticsearch
    sleep 30
    systemctl start kibana
    sleep 20

    filebeat setup --dashboards --pipelines --index-management
    systemctl start filebeat
  EOF
}

########################################
# VM
########################################
resource "google_compute_instance" "siem_vm" {
  name         = var.vm_name
  machine_type = "e2-small"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    subnetwork = var.subnet_name
    access_config {}
  }

  metadata = {
    startup-script = local.startup_script
  }
}
