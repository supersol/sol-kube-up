# export GOOGLE_APPLICATION_CREDENTIALS="[PATH_TO_CREDS/SOME_CREDS.json]"
# export GOOGLE_PROJECT="YOUR_PROJECT_NAME"
# b,c,d
provider "google" {
  region      = "europe-west1"
}

resource "google_compute_network" "kube_network" {
  name                    = "${terraform.workspace}-kube-network"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "kube_subnetwork" {
  ip_cidr_range = "10.240.0.0/24"
  name          = "${terraform.workspace}-kube-network-range"
  network       = "${google_compute_network.kube_network.self_link}"
}


resource "google_compute_firewall" "kube-internal" {
  name = "kube-firewall-internal"
  network = "${google_compute_network.kube_network.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]
}

resource "google_compute_firewall" "kube-external" {
  name = "kube-firewall-external"
  network = "${google_compute_network.kube_network.self_link}"

  allow {
    protocol = "tcp"
    ports = ["22", "6443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}