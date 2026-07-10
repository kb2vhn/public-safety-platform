package main

import (
	"crypto/aes"
	"crypto/cipher" // Added for GCM encryption
	"crypto/rand"
	"encoding/base64"
	"flag"
	"fmt"
	"io" // Added for reading the random nonce
	"log"
)

// Encrypt handles the AES-GCM encryption and returns a Base64 string
func Encrypt(plaintext string, key []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	// Create a unique nonce (number used once) for this encryption
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	// Encrypt and append the nonce to the front of the ciphertext
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)

	// Return as Base64 so it fits cleanly in your config.yaml
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func main() {
	flag.Parse() 

	// 1. Generate a brand new cryptographically secure 32-byte key
	keyBytes := make([]byte, 32)
	if _, err := rand.Read(keyBytes); err != nil {
		log.Fatalf("Failed to generate key: %v", err)
	}
	base64Key := base64.StdEncoding.EncodeToString(keyBytes)

	// 2. Setup your plain Active Directory password flag
	plainPassword := flag.String("password", "SuperSecretServiceAccountPassword123!", "password to be converted")

	encryptedPassword, err := Encrypt(*plainPassword, keyBytes)
	if err != nil {
		log.Fatalf("Encryption failed: %v", err)
	}

	fmt.Println("=== 1. SAVE THIS AS YOUR WINDOWS ENVIRONMENT VARIABLE ===")
	fmt.Printf("Variable Name: APP_SECRET_KEY\n")
	fmt.Printf("Variable Value: %s\n\n", base64Key)

	fmt.Println("=== 2. PASTE THIS INTO YOUR CONFIG.YAML ===")
	fmt.Printf("BindPassword: \"%s\"\n", encryptedPassword)
}
// tested July 3, 2026 
//:!go run .
//=== 1. SAVE THIS AS YOUR WINDOWS ENVIRONMENT VARIABLE ===
//Variable Name: APP_SECRET_KEY
//Variable Value: nMvDUS7ztab2Fp0dNmbbCkj6esKYsGE02TzxfKKtN5M=

//=== 2. PASTE THIS INTO YOUR CONFIG.YAML ===
//BindPassword: "NuJhdEtBaEE5ir5gZBflD/LzEDfyoPZ3N8uPX5TXzd7D60IcYvDI1lJc/XQ2T2yYYd3oIJs="
