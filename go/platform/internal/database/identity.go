// Package database owns the production process-to-PostgreSQL identity boundary,
// bounded pgx pool creation, and startup compatibility checks.
package database

// ServiceIdentity binds one production process to its exact accepted
// PostgreSQL login role.
type ServiceIdentity struct {
	ProcessName    string
	PostgreSQLRole string
}

var (
	// FoundationAPI is the bounded identity for the Foundation API process.
	FoundationAPI = ServiceIdentity{
		ProcessName:    "foundation-api",
		PostgreSQLRole: "issp_service_authorization",
	}

	// IntegrationDeliveryWorker is the bounded identity for integration
	// outbox delivery.
	IntegrationDeliveryWorker = ServiceIdentity{
		ProcessName:    "integration-delivery-worker",
		PostgreSQLRole: "issp_service_integration_delivery",
	}

	// MonitoringDeliveryWorker is the bounded identity for monitoring
	// delivery work.
	MonitoringDeliveryWorker = ServiceIdentity{
		ProcessName:    "monitoring-delivery-worker",
		PostgreSQLRole: "issp_service_monitoring_delivery",
	}
)

// All returns the complete process identity inventory as a fixed-size value so
// callers cannot mutate package-owned state.
func All() [3]ServiceIdentity {
	return [3]ServiceIdentity{
		FoundationAPI,
		IntegrationDeliveryWorker,
		MonitoringDeliveryWorker,
	}
}

// ByPostgreSQLRole returns the exact compiled service identity for a role.
func ByPostgreSQLRole(role string) (ServiceIdentity, bool) {
	for _, identity := range All() {
		if identity.PostgreSQLRole == role {
			return identity, true
		}
	}
	return ServiceIdentity{}, false
}
