# gcp_webapp

# Terraform Deployment na GCP

Ten projekt zawiera skrypty Terraform, które pozwalają na wdrożenie infrastruktury w Google Cloud Platform (GCP). Infrastruktura obejmuje:
- Sieć VPC oraz podsieć
- Instancje Compute Engine (konfigurowane za pomocą szablonu)
- Managed Instance Group (MIG) z autoskalowaniem i health check
- Load Balancer z globalnym adresem IP
- Cloud SQL (MySQL) wraz z bazą danych i użytkownikiem
- Bucket w Cloud Storage
- Reguły firewall dla ruchu HTTP/HTTPS

## Co znajdziesz w repozytorium

- **main.tf** – główny plik konfiguracyjny Terraform, zawierający definicje zasobów.
- **variables.tf** – plik z deklaracjami zmiennych (region i strefa).
- **outputs.tf** – plik z wyjściami, dzięki którym po wdrożeniu zobaczysz najważniejsze informacje (adres IP load balancera, IP bazy danych, nazwa bucketu).
