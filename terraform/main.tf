// Configure the Google Cloud Provider
provider "google" {
  credentials = file(var.service_key_path)
  project     = var.project_name
  region      = var.region_name
  zone        = var.zone_name
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
  byte_length = 8
}

// Creates a static public IP address for our google compute instance to utilize
resource "google_compute_address" "static" {
  name = "ipv4-address"
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "validator" {
  name         = "kusama-${random_id.instance_id.hex}"
  machine_type = var.machine_type
  zone         = var.zone_name

  boot_disk {
    initialize_params {
      image = var.image_name
      size  = var.image_size
    }
  }

  metadata = {
    ssh-keys = "${var.username}:${file(var.public_key_path)}"
  }

  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external IP address
      nat_ip = google_compute_address.static.address
    }
  }

  provisioner "file" {
    source = "../scripts/${var.script_name}"
    destination = "/tmp/${var.script_name}"

    connection {
      type        = "ssh"
      host        = google_compute_address.static.address
      user        = var.username
      private_key = file(var.private_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/${var.script_name}",
      "[ -z ${var.node_name} ] && NAME_FLAG='' || NAME_FLAG='-n ${var.node_name}'",
      "[ -z ${var.telemetry_url} ] && TELEMETRY_FLAG='' || TELEMETRY_FLAG='-t ${var.telemetry_url}'",
      "[ -z ${var.db_url} ] && DB_FLAG='' || DB_FLAG='-d ${var.db_url}'",
      "/tmp/${var.script_name} $NAME_FLAG $TELEMETRY_FLAG $DB_FLAG "
    ]
        
    connection {
      type        = "ssh"
      host        = google_compute_address.static.address
      user        = var.username
      private_key = file(var.private_key_path)
    }
  }
}

module "session_key" {
  source  = "matti/resource/shell"
  command = "ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ${var.username}@${google_compute_instance.validator.network_interface.0.access_config.0.nat_ip} 'cat session_key'"

  depends = [google_compute_instance.validator]
}

output "session_key" {
  value = module.session_key.stdout
}

// A variable for extracting the external ip of the instance
output "ip" {
  value = "${google_compute_instance.validator.network_interface.0.access_config.0.nat_ip}"
  sensitive = true
}