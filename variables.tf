# Deklaracja zmiennej 'region'
variable "region" {
  description = "Region GCP"      # Opis zmiennej – wskazuje, że określa region w Google Cloud
  default     = "europe-central2" # Wartość domyślna ustawiona na 'europe-central2'
}

# Deklaracja zmiennej 'zone'
variable "zone" {
  description = "Strefa GCP"      # Opis zmiennej – wskazuje, że określa strefę w Google Cloud
  default     = "europe-central2-a" # Wartość domyślna ustawiona na 'europe-central2-a'
}
