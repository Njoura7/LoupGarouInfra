output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server URL"
}

output "aks_kube_config" {
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
  description = "AKS kubeconfig"
}

output "sql_server_fqdn" {
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
  description = "SQL Server fully qualified domain name"
}