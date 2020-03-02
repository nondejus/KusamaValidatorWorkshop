// Configure the Google Cloud Provider
provider "google" {
  credentials = file(var.service_key_path)
  project     = var.project_name
  region      = var.region_name
  zone        = var.zone_name
}

// Sentry Node

// Terraform plugin for creating random ids
resource "random_id" "sentry_instance_id" {
  byte_length = 8
}

// Creates a static public IP address for our Sentry Node
resource "google_compute_address" "static_sentry_ip" {
  name = "sentry-ipv4-address"
}

// Sentry Node
resource "google_compute_instance" "sentry" {
  name         = "kusama-${random_id.sentry_instance_id.hex}"
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
      nat_ip = google_compute_address.static_sentry_ip.address
    }
  }

  // todo change sentry id script name
  provisioner "file" {
    source      = "../scripts/setup-sentry.sh"
    destination = "/tmp/setup-sentry.sh"

    connection {
      type        = "ssh"
      host        = google_compute_address.static_sentry_ip.address
      user        = var.username
      private_key = file(var.private_key_path)
    }
  }

  // todo rename setry script
  provisioner "remote-exec" {
    inline = [
      "[ -z ${var.node_name} ] && NAME_FLAG='' || NAME_FLAG='-n sentry_n'",
      "[ -z ${var.telemetry_url} ] && TELEMETRY_FLAG='' || TELEMETRY_FLAG='-t ${var.telemetry_url}'",
      "[ -z ${var.db_url} ] && DB_FLAG='' || DB_FLAG='-d ${var.db_url}'",
      "chmod +x /tmp/setup-sentry.sh",
      "/tmp/setup-sentry.sh $NAME_FLAG $TELEMETRY_FLAG $DB_FLAG "
    ]

    connection {
      type        = "ssh"
      host        = google_compute_address.static_sentry_ip.address
      user        = var.username
      private_key = file(var.private_key_path)
    }
  }

  depends_on= [google_compute_address.static_validator_ip]
}

// A variable for extracting the external ip of the sentry node
output "sentry_ip" {
  value     = "${google_compute_instance.sentry.network_interface.0.access_config.0.nat_ip}"
  sensitive = true
}

module "sentry_peer_id" {
  source  = "matti/resource/shell"
  command = "ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ${var.username}@${google_compute_instance.sentry.network_interface.0.access_config.0.nat_ip} 'cat peerId'"

  depends = [google_compute_instance.sentry]
}

output "sentry_peer_id" {
  value = module.sentry_peer_id.stdout
}


// Validator Node

// Terraform plugin for creating random ids
resource "random_id" "validator_instance_id" {
  byte_length = 8
}

// Creates a static public IP address for our Validator Node
resource "google_compute_address" "static_validator_ip" {
  name = "validator-ipv4-address"
}

// Create a Validator Instance
resource "google_compute_instance" "validator" {
  name         = "kusama-${random_id.validator_instance_id.hex}"
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
      // Gives the VM an external IP address
      nat_ip = google_compute_address.static_validator_ip.address
    }
  }

  provisioner "file" {
    source      = "../scripts/${var.script_name}"
    destination = "/tmp/${var.script_name}"

    connection {
      type        = "ssh"
      host        = google_compute_address.static_validator_ip.address
      user        = var.username
      private_key = file(var.private_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "[ -z ${var.node_name} ] && NAME_FLAG='' || NAME_FLAG='-n ${var.node_name}'",
      "[ -z ${var.telemetry_url} ] && TELEMETRY_FLAG='' || TELEMETRY_FLAG='-t ${var.telemetry_url}'",
      "[ -z ${var.db_url} ] && DB_FLAG='' || DB_FLAG='-d ${var.db_url}'",
      "[ -z ${module.sentry_peer_id.stdout} ] && RESERVED_FLAG='' || RESERVED_FLAG='-r /ip4/${google_compute_address.static_sentry_ip.address}/tcp/30333/p2p/${module.sentry_peer_id.stdout}'",
      "chmod +x /tmp/${var.script_name}",
      "/tmp/${var.script_name} $NAME_FLAG $TELEMETRY_FLAG $DB_FLAG $RESERVED_FLAG"
    ]

    connection {
      type        = "ssh"
      host        = google_compute_address.static_validator_ip.address
      user        = var.username
      private_key = file(var.private_key_path)
    }
  }

  depends_on = [google_compute_instance.sentry]
}

// Fetches the session key file from the VM
module "session_key" {
  source  = "matti/resource/shell"
  command = "ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ${var.username}@${google_compute_instance.validator.network_interface.0.access_config.0.nat_ip} 'cat session_key'"

  depends = [google_compute_address.static_validator_ip.address, google_compute_instance.validator]
}

// The result of the author_rotateKeys RPC call
output "session_key" {
  value = module.session_key.stdout
}

// A variable for extracting the external ip of the instance
output "validator_ip" {
  value     = "${google_compute_instance.validator.network_interface.0.access_config.0.nat_ip}"
  sensitive = true
}