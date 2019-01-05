// export GOOGLE_APPLICATION_CREDENTIALS="[PATH_TO_CREDS/SOME_CREDS.json]"
// export GOOGLE_PROJECT="YOUR_PROJECT_NAME"
provider "google" {
  region = "europe-west1"
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
    ports = ["22", "6443"]
  }

  allow {
    protocol = "icmp"
  }

}

resource "google_compute_address" "ip_address" {
  name = "kube-ip-address"
}

resource "google_compute_instance" "kube-controller-" {
  count          = "${var.node_count}"
  name           = "kube-controller-${count.index}"
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

  metadata_startup_script = "apt install python"
}

resource "google_compute_instance" "kube-worker-" {
  count          = "${var.node_count}"
  name           = "kube-worker-${count.index}"
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

  metadata_startup_script = "apt install python"
}
