package database

import "testing"

func TestServiceIdentityInventory(t *testing.T) {
	t.Parallel()

	want := [3]ServiceIdentity{
		{ProcessName: "foundation-api", PostgreSQLRole: "issp_service_authorization"},
		{ProcessName: "integration-delivery-worker", PostgreSQLRole: "issp_service_integration_delivery"},
		{ProcessName: "monitoring-delivery-worker", PostgreSQLRole: "issp_service_monitoring_delivery"},
	}

	got := All()
	if got != want {
		t.Fatalf("identity inventory mismatch: got %#v want %#v", got, want)
	}

	seenProcesses := make(map[string]struct{}, len(got))
	seenRoles := make(map[string]struct{}, len(got))

	for _, identity := range got {
		if identity.ProcessName == "" || identity.PostgreSQLRole == "" {
			t.Fatalf("identity contains an empty field: %#v", identity)
		}
		if _, exists := seenProcesses[identity.ProcessName]; exists {
			t.Fatalf("duplicate process name: %s", identity.ProcessName)
		}
		if _, exists := seenRoles[identity.PostgreSQLRole]; exists {
			t.Fatalf("duplicate PostgreSQL role: %s", identity.PostgreSQLRole)
		}
		seenProcesses[identity.ProcessName] = struct{}{}
		seenRoles[identity.PostgreSQLRole] = struct{}{}
	}
}
