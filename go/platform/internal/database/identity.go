// Package database defines the production process-to-database identity
// boundary. Step 2 declares identities only; it does not open a connection.
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

// All returns the complete Step 2 process identity inventory as a fixed-size
// value so callers cannot mutate package-owned state.
func All() [3]ServiceIdentity {
	return [3]ServiceIdentity{
		FoundationAPI,
		IntegrationDeliveryWorker,
		MonitoringDeliveryWorker,
	}
}
