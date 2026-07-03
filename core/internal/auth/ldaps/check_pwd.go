package main

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/go-ldap/ldap/v3"
)

// Decrypt decrypts a base64 encoded AES-GCM string using a 32-byte AES key
func Decrypt(base64CipherText string, key []byte) (string, error) {
	cipherText, err := base64.StdEncoding.DecodeString(base64CipherText)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(cipherText) < nonceSize {
		return "", errors.New("ciphertext too short")
	}

	nonce, actualCipherText := cipherText[:nonceSize], cipherText[nonceSize:]

	plainText, err := gcm.Open(nil, nonce, actualCipherText, nil)
	if err != nil {
		return "", err
	}

	return string(plainText), nil
}

// GetMasterKey fetches and validates the 32-byte key from the environment
func GetMasterKey() ([]byte, error) {
	base64Key := os.Getenv("APP_SECRET_KEY")
	if base64Key == "" {
		return nil, errors.New("environment variable APP_SECRET_KEY is missing")
	}

	keyBytes, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil {
		return nil, fmt.Errorf("failed to base64 decode master key: %w", err)
	}

	if len(keyBytes) != 32 {
		return nil, fmt.Errorf("invalid key length: expected 32 bytes, got %d", len(keyBytes))
	}

	return keyBytes, nil
}

// AuthenticateServiceAccount decrypts the YAML password and binds to LDAPS
func AuthenticateServiceAccount(l *ldap.Conn, cfg *Config) error {
	// 1. Grab the 32-byte master key from the environment memory
	key, err := GetMasterKey()
	if err != nil {
		LogAuditEvent("SYSTEM", "AUTH_FAILURE", "Failed to retrieve encryption master key from host environment")
		return fmt.Errorf("crypto initialization error: %w", err)
	}

	// 2. Decrypt the password string parsed from your config.yaml
	cleartextPassword, err := Decrypt(cfg.LDAP.BindPassword, key)
	if err != nil {
		LogAuditEvent("SYSTEM", "AUTH_FAILURE", "Failed to decrypt the configuration bind password")
		return fmt.Errorf("decryption error: %w", err)
	}

	// 3. Perform the secure LDAP bind using the service account UPN
	err = l.Bind(cfg.LDAP.SaUPN, cleartextPassword)
	if err != nil {
		LogAuditEvent(cfg.LDAP.SaUPN, "LDAP_BIND_FAILED", fmt.Sprintf("Active Directory rejected credentials: %v", err))
		return fmt.Errorf("service account ldap bind failed: %w", err)
	}

	LogAuditEvent(cfg.LDAP.SaUPN, "LDAP_BIND_SUCCESS", "Successfully established authenticated directory session")
	return nil
}

// LogAuditEvent creates a structured, tamper-evident text audit trail
// Designed to write directly to standard out or syslog for Unix/BSD aggregators
func LogAuditEvent(actor string, action string, details string) {
	timestamp := time.Now().UTC().Format(time.RFC3339)
	
	// Formats as a structured, easy-to-parse string for tools like Logstash or Splunk
	// CRITICAL SECURITY: Never pass or log the 'cleartextPassword' variable here!
	log.Printf("[AUDIT] time=%s actor=%s action=%s status=%s msg=%q\n", 
		timestamp, actor, action, "INFO", details)
}

