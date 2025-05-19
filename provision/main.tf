provider "google" {
  project = "terraform-checkov"
  region  = "us-central1"
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 8.0"

  project_id   = "terraform-checkov"
  network_name = "my-vpc-network"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name   = "subnet-1"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "us-central1"
    },
  ]
}

resource "google_compute_instance" "vm_instance" {
  count        = 2
  name         = "vm-instance-${count.index}"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = module.vpc.subnets["us-central1/subnet-1"].self_link

    access_config {
      // Ephemeral public IP
    }
  }

  tags = ["web"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    systemctl start apache2
    echo "Hello from $(hostname)" > /var/www/html/index.html
  EOF
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = module.vpc.network_name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

locals {
  instance_self_links = [
    for instance in google_compute_instance.vm_instance : instance.self_link
  ]
}

resource "google_compute_instance_group" "web_group" {
  name      = "web-group"
  zone      = "us-central1-a"
  instances = local.instance_self_links

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_health_check" "http" {
  name = "http-health-check"

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "web" {
  name                  = "web-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.http.self_link]

  backend {
    group = google_compute_instance_group.web_group.self_link
  }
}

resource "google_compute_url_map" "web" {
  name            = "web-url-map"
  default_service = google_compute_backend_service.web.self_link
}

resource "google_compute_target_http_proxy" "web" {
  name    = "web-http-proxy"
  url_map = google_compute_url_map.web.self_link
}

resource "google_compute_global_forwarding_rule" "web" {
  name       = "web-forwarding-rule"
  target     = google_compute_target_http_proxy.web.self_link
  port_range = "80"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
}
