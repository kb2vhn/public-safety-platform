package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"os"

	"github.com/go-ldap/ldap/v3"
	"go.yaml.in/yaml/v4"
)

type Config struct {
	LDAP LdapConfig `yaml:"server"` // Capitalized field name to export it
}

// LdapConfig holds your settings. Capitalized fields are required for YAML parsing!
type LdapConfig struct {
	FQDN         string `yaml:"fqdn"`
	Port         int    `yaml:"port"`
	BaseDN       string `yaml:"baseDN"`
	Cert         string `yaml:"caCert"`
	SaUPN        string `yaml:"saUPN"`
	BindPassword string `yaml:"bindPassword"`
}

// LoadConfig reads and parses your local configuration file
func LoadConfig(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	var config Config
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return nil, err
	}
	return &config, nil
}

func connectLDAPS() (*ldap.Conn, error) {
	cfg, err := LoadConfig("ldap_config.yaml")
	if err != nil {
		// Fixed: Changed Fatalln to Fatalf to support format verbs like %v
		log.Fatalf("Failed to load LDAP configuration settings: %v", err)
	}

	addr := fmt.Sprintf("%s:%d", cfg.LDAP.FQDN, cfg.LDAP.Port)

	// Base TLS Configuration
	tlsConfig := &tls.Config{
		ServerName:         cfg.LDAP.FQDN, // Must match the certificate Common Name / SAN
		InsecureSkipVerify: false,         // Explicitly enforce certificate safety
	}

	// Read and append the custom CA certificate file path from the YAML config
	if cfg.LDAP.Cert != "" {
		caCertBytes, err := os.ReadFile(cfg.LDAP.Cert) // Fixed: Read the certificate file off disk
		if err != nil {
			return nil, fmt.Errorf("failed to read CA certificate file: %w", err)
		}

		certPool := x509.NewCertPool()
		if ok := certPool.AppendCertsFromPEM(caCertBytes); !ok {
			return nil, fmt.Errorf("failed to parse CA certificate PEM data")
		}
		tlsConfig.RootCAs = certPool
	}

	// Dial the secure LDAPS server directly
	l, err := ldap.DialURL(addr, ldap.DialWithTLSConfig(tlsConfig))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to LDAPS: %w", err)
	}
	return l, nil
}

func main() {
	// Simple test execution to confirm everything compiles and runs
	conn, err := connectLDAPS()
	if err != nil {
		log.Fatalf("LDAPS Connection failed: %v", err)
	}
	defer conn.Close()

	fmt.Println("Successfully established an encrypted LDAPS connection layer!")
}
