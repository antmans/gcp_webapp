# Wyjście definiujące adres IP load balancera
output "load_balancer_ip" {
  value = google_compute_global_address.web_lb_ip.address  # Zwraca właściwy adres IP przypisany do load balancera
}

# Wyjście definiujące prywatny adres IP instancji bazy danych
output "database_ip" {
  value = google_sql_database_instance.web_db.private_ip_address  # Zwraca prywatny adres IP instancji Cloud SQL
}

# Wyjście definiujące nazwę bucketu w Cloud Storage
output "bucket_name" {
  value = google_storage_bucket.web_bucket.name  # Zwraca nazwę utworzonego bucketu
}
