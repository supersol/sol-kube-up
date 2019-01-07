// export GOOGLE_APPLICATION_CREDENTIALS="[PATH_TO_CREDS/SOME_CREDS.json]"
// export GOOGLE_PROJECT="YOUR_PROJECT_NAME"
provider "google" {
  region = "europe-west1"
}

variable "region" {
  default = "europe-west1"
}

variable "node_count" {
  default = "3"
}

variable "zones" {
  type    = "list"
  default = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
}

resource "google_compute_network" "kube_network" {
  name                    = "${terraform.workspace}-kube-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "kube_subnetwork" {
  ip_cidr_range = "10.240.0.0/24"
  name          = "${terraform.workspace}-kube-network-subnet"
  network       = "${google_compute_network.kube_network.self_link}"
}


resource "google_compute_firewall" "kube-internal" {
  name          = "kube-firewall-internal"
  network       = "${google_compute_network.kube_network.self_link}"
  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

}

resource "google_compute_firewall" "kube-external" {
  name          = "kube-firewall-external"
  network       = "${google_compute_network.kube_network.self_link}"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  allow {
    protocol = "icmp"
  }

}

resource "google_compute_firewall" "kube-allow-healthz" {
  name          = "kube-allow-healthz"
  network       = "${google_compute_network.kube_network.self_link}"
  source_ranges = ["209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_http_health_check" "healthz" {
  name         = "kube-healthz"
  description  = "kuber health check"
  host         = "kubernetes.default.svc.cluster.local"
  request_path = "/healthz"
}

# TODO: set instances dynamcally, how? =\
resource "google_compute_target_pool" "kube-target-pool" {
  name          = "kube-target-pool"
  health_checks = ["kube-healthz"]
  instances     = ["europe-west1-b/controller-0",
                   "europe-west1-c/controller-1",
                   "europe-west1-d/controller-2"]
}

resource "google_compute_forwarding_rule" "kube-forward-rule" {
  name       = "kube-forward-rule"
  ip_address = "${google_compute_address.ip_address.address}"
  port_range = "6443"
  region     = "${var.region}"
  target     = "${google_compute_target_pool.kube-target-pool.self_link}"
}

resource "google_compute_route" "kube-route-" {
  count       = "${var.node_count}"
  dest_range  = "10.200.${count.index}.0/24"
  name        = "kube-route-${count.index}"
  network     = "${google_compute_network.kube_network.name}"
  next_hop_ip = "10.240.0.2${count.index}"
}

resource "google_compute_address" "ip_address" {
  name = "kube-ip-address"
}

resource "google_compute_instance" "controller-" {
  count          = "${var.node_count}"
  name           = "controller-${count.index}"
  machine_type   = "n1-standard-1"
  zone           = "${var.zones["${count.index}"]}"
  tags           = ["${terraform.workspace}-kubernetes", "controller"]

  can_ip_forward = "true"

  boot_disk {
    initialize_params {
      size = 20
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.kube_subnetwork.self_link}"
    network_ip = "10.240.0.1${count.index}"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata_startup_script = "apt install python -y"
}

resource "google_compute_instance" "worker-" {
  count          = "${var.node_count}"
  name           = "worker-${count.index}"
  machine_type   = "n1-standard-1"
  zone           = "${var.zones["${count.index}"]}"
  tags           = ["${terraform.workspace}-kubernetes", "worker"]
  can_ip_forward = "true"

  boot_disk {
    initialize_params {
      size  = 20
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  metadata {
    pod-cidr = "10.200.${count.index}.0/24"
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.kube_subnetwork.self_link}"
    network_ip    = "10.240.0.2${count.index}"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata_startup_script = "apt install python -y"
}
