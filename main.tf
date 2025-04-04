# main.tf

# Definicja sieci VPC – nie tworzy automatycznych podsieci
resource "google_compute_network" "web_network" {
  name                    = "web-network"          # Ustawia nazwę sieci VPC
  auto_create_subnetworks = false                  # Wyłącza automatyczne tworzenie podsieci
}

# Definicja podsieci w obrębie utworzonej sieci VPC
resource "google_compute_subnetwork" "web_subnet" {
  name          = "web-subnet"                     # Ustawia nazwę podsieci
  network       = google_compute_network.web_network.id  # Powiązanie z utworzoną siecią VPC
  ip_cidr_range = "10.0.1.0/24"                    # Definiuje zakres adresów IP dla podsieci
  region        = var.region                       # Ustawia region na podstawie zmiennej
}

# Szablon instancji Compute Engine – definiuje konfigurację maszyn
resource "google_compute_instance_template" "web_template" {
  name         = "web-template"                   # Nazwa szablonu instancji
  machine_type = "e2-micro"                       # Określa typ maszyny (e2-micro)
  image_project = "debian-cloud"                  # Projekt, z którego pobierany jest obraz systemu
  image        = "debian-11"                      # Wersja obrazu (Debian 11)

  # Konfiguracja interfejsu sieciowego
  network_interface {
    network    = google_compute_network.web_network.id   # Łączy instancję z siecią VPC
    subnetwork = google_compute_subnetwork.web_subnet.id   # Łączy instancję z podsiecią
  }

  # Metadane przekazywane do instancji – zawiera skrypt uruchomieniowy
  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      apt-get update                                  # Aktualizacja listy pakietów
      apt-get install -y nginx                        # Instalacja Nginx
      echo "<html><body><h1>Hello from $(hostname)</h1></body></html>" > /var/www/html/index.html  # Utworzenie strony domowej z nazwą hosta
      systemctl start nginx                           # Uruchomienie usługi Nginx
    EOF
  }

  tags = ["http-server", "https-server"]              # Przypisanie tagów – użytecznych przy regułach firewall
}

# Grupa zarządzana instancji (Managed Instance Group – MIG)
resource "google_compute_managed_instance_group" "web_mig" {
  name               = "web-mig"                                      # Nazwa grupy instancji
  instance_template  = google_compute_instance_template.web_template.id  # Szablon instancji używany do tworzenia maszyn
  base_instance_name = "web-instance"                               # Prefiks nazw dla instancji w grupie
  zone               = var.zone                                       # Strefa, w której grupa zostanie utworzona
  target_size        = 2                                              # Docelowa liczba instancji w grupie

  # Polityka automatycznego naprawiania instancji
  auto_healing_policies {
    health_check = google_compute_health_check.web_health_check.id         # Odwołanie do zasobu health check
  }
}

# Health Check – sprawdza dostępność instancji poprzez HTTP
resource "google_compute_health_check" "web_health_check" {
  name = "web-health-check"                             # Nazwa health checka
  http_health_check {
    port = 80                                         # Port, na którym przeprowadzane jest sprawdzanie
  }
}

# Autoskaler – skalowanie grupy instancji w zależności od obciążenia
resource "google_compute_autoscaler" "web_autoscaler" {
  name   = "web-autoscaler"                             # Nazwa autoskalera
  target = google_compute_managed_instance_group.web_mig.id  # Odwołanie do grupy instancji, którą będzie skalował
  zone   = var.zone                                   # Strefa działania autoskalera

  autoscaling_policy {
    max_replicas    = 5                              # Maksymalna liczba instancji
    min_replicas    = 2                              # Minimalna liczba instancji
    target_cpu_utilization = 0.6                     # Docelowe wykorzystanie CPU (60%)
  }
}

# Load Balancer – konfiguracja globalnego adresu IP oraz dystrybucji ruchu

# Globalny adres IP dla load balancera
resource "google_compute_global_address" "web_lb_ip" {
  name = "web-lb-ip"                                  # Nazwa globalnego adresu IP
}

# Usługa backend – definiuje zasób, do którego kierowany jest ruch
resource "google_compute_backend_service" "web_backend_service" {
  name                  = "web-backend-service"           # Nazwa usługi backend
  protocol              = "HTTP"                          # Protokół komunikacji (HTTP)
  load_balancing_scheme = "EXTERNAL"                      # Ustawienie load balancera jako zewnętrznego
  health_checks         = [google_compute_health_check.web_health_check.id]  # Lista health checków monitorujących backend

  backend {
    group = google_compute_managed_instance_group.web_mig.id   # Odwołanie do grupy zarządzanych instancji
  }
}

# Mapowanie URL – określa, która usługa obsługuje zapytania HTTP
resource "google_compute_url_map" "web_url_map" {
  name            = "web-url-map"                     # Nazwa mapowania URL
  default_service = google_compute_backend_service.web_backend_service.id  # Ustawia domyślną usługę backend (poprawione)
}

# HTTP Proxy – przekierowuje ruch HTTP na podstawie mapowania URL
resource "google_compute_target_http_proxy" "web_http_proxy" {
  name    = "web-http-proxy"                           # Nazwa HTTP proxy
  url_map = google_compute_url_map.web_url_map.id       # Odwołanie do mapowania URL (poprawione)
}

# Globalna reguła przekierowania – przypisuje ruch przychodzący do HTTP proxy
resource "google_compute_global_forwarding_rule" "web_forwarding_rule" {
  name       = "web-forwarding-rule"                   # Nazwa reguły przekierowania
  target     = google_compute_target_http_proxy.web_http_proxy.id  # Odwołanie do HTTP proxy
  port_range = "80"                                    # Przekierowuje ruch przychodzący na port 80
  ip_address = google_compute_global_address.web_lb_ip.address  # Używa faktycznego adresu IP zdefiniowanego w zasobie global_address (poprawione)
}

# Cloud SQL – konfiguracja instancji bazy danych MySQL

# Definicja instancji bazy danych Cloud SQL
resource "google_sql_database_instance" "web_db" {
  name             = "web-db"                          # Nazwa instancji bazy danych
  region           = var.region                        # Region działania instancji
  database_version = "MYSQL_8_0"                       # Wersja bazy (MySQL 8.0)

  settings {
    tier = "db-f1-micro"                              # Klasa instancji bazy danych

    ip_configuration {
      ipv4_enabled    = false                        # Wyłącza przydzielanie publicznego adresu IPv4
      private_network = google_compute_network.web_network.id  # Ustawia prywatną sieć VPC dla instancji
    }
  }
}

# Definicja bazy danych w instancji Cloud SQL
resource "google_sql_database" "web_db_database" {
  name     = "web-db-database"                        # Nazwa bazy danych
  instance = google_sql_database_instance.web_db.name # Odwołanie do instancji Cloud SQL
}

# Definicja użytkownika bazy danych
resource "google_sql_user" "web_db_user" {
  name     = "web-db-user"                            # Nazwa użytkownika bazy danych
  instance = google_sql_database_instance.web_db.name # Instancja, do której przypisany jest użytkownik
  password = "password"                               # Hasło użytkownika (zalecane stosowanie zmiennych lub menedżera sekretów)
}

# Cloud Storage – konfiguracja bucketu na pliki

# Definicja bucketu w Cloud Storage
resource "google_storage_bucket" "web_bucket" {
  name     = "web-bucket"                             # Nazwa bucketu (musi być unikalna)
  location = var.region                               # Lokalizacja bucketu, ustalana przez zmienną
}

# Konfiguracja reguł zapory (Firewall)

# Reguła zapory umożliwiająca ruch HTTP z load balancera
resource "google_compute_firewall" "allow_lb_http" {
  name    = "allow-lb-http"                           # Nazwa reguły firewall
  network = google_compute_network.web_network.id      # Sieć, do której odnosi się reguła

  allow {
    protocol = "tcp"                                 # Zezwala na ruch TCP
    ports    = ["80"]                                # Tylko port 80 (HTTP)
  }

  source_ranges = [google_compute_global_address.web_lb_ip.address]  # Ogranicza ruch do adresu load balancera
}

# Reguła zapory umożliwiająca ruch HTTP i HTTPS z dowolnego źródła
resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"                        # Nazwa reguły firewall
  network = google_compute_network.web_network.id       # Sieć, do której odnosi się reguła

  allow {
    protocol = "tcp"                                 # Zezwala na ruch TCP
    ports    = ["80", "443"]                         # Porty 80 (HTTP) i 443 (HTTPS)
  }

  source_ranges = ["0.0.0.0/0"]                       # Zezwala na ruch z dowolnego adresu IP
}
