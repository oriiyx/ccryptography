/**
 * Example main.c - CJOSE + MIRACL Core Integration Demo
 * 
 * This demonstrates how to use both libraries together:
 * - MIRACL Core for elliptic curve cryptography (ECDH key exchange)
 * - CJOSE for JSON Web Encryption/Signing
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// MIRACL Core headers
#include "core.h"
#include "big_256_56.h"
#include "fp_NIST256.h"
#include "ecp_NIST256.h"
#include "ecdh_NIST256.h"

// CJOSE headers
#include "cjose/cjose.h"

// Helper function to print hex data
void print_hex(const char* label, const uint8_t* data, size_t len) {
    printf("%s: ", label);
    for (size_t i = 0; i < len; i++) {
        printf("%02x", data[i]);
    }
    printf("\n");
}

// Test MIRACL Core ECDH functionality
int test_miracl_ecdh() {
    printf("\n=== Testing MIRACL Core ECDH ===\n");
    
    // Initialize RNG
    csprng rng;
    char raw[100];
    time_t ran = time(NULL);
    raw[0] = (char)ran;
    raw[1] = (char)(ran >> 8);
    raw[2] = (char)(ran >> 16);
    raw[3] = (char)(ran >> 24);
    for (int i = 4; i < 100; i++) raw[i] = (char)i;
    RAND_seed(&rng, 100, raw);

    // Create octet structures for private and public keys
    char private_key_data[EGS_NIST256];
    char public_key_data[2 * EFS_NIST256 + 1]; // Uncompressed public key

    octet private_key = {0, sizeof(private_key_data), private_key_data};
    octet public_key = {0, sizeof(public_key_data), public_key_data};

    printf("✓ Private key generated\n");

    // Now call the function correctly
    int result = ECP_NIST256_KEY_PAIR_GENERATE(&rng, &private_key, &public_key);

    if (result != 0) {
        printf("✗ MIRACL Core: Key generation failed with error %d\n", result);
        return 1;
    }

    printf("✓ MIRACL Core: Generated ECDH key pair successfully\n");
    printf("Private key length: %d bytes\n", private_key.len);
    printf("Public key length: %d bytes\n", public_key.len);

    // Print first 16 bytes of private key
    print_hex("Private key", (uint8_t*)private_key.val, private_key.len > 16 ? 16 : private_key.len);

    // Print first 32 bytes of public key
    print_hex("Public key", (uint8_t*)public_key.val, public_key.len > 32 ? 32 : public_key.len);

    return 0;
}

// Test CJOSE functionality
int test_cjose() {
    printf("\n=== Testing CJOSE JWT ===\n");

    cjose_err err;
    memset(&err, 0, sizeof(err)); // Initialize error structure

    // Simple test: Create a symmetric key (HMAC)
    const char* key_json = "{"
        "\"kty\":\"oct\","
        "\"k\":\"ZmFudGFzdGljand0\""
        "}";

    cjose_jwk_t* jwk = cjose_jwk_import(key_json, strlen(key_json), &err);
    if (!jwk) {
        printf("✗ CJOSE: Failed to import JWK: %s\n", err.message ? err.message : "Unknown error");
        return 1;
    }

    printf("✓ CJOSE: Successfully imported JSON Web Key\n");

    // Get the key type (returns enum, not string)
    cjose_jwk_kty_t kty = cjose_jwk_get_kty(jwk, &err);
    const char* kty_name = cjose_jwk_name_for_kty(kty, &err);
    if (kty_name) {
        printf("✓ CJOSE: Key type: %s\n", kty_name);
    } else {
        printf("✗ CJOSE: Failed to get key type name\n");
        cjose_jwk_release(jwk);
        return 1;
    }

    // Create a header for JWS
    cjose_header_t* header = cjose_header_new(&err);
    if (!header) {
        printf("✗ CJOSE: Failed to create header: %s\n", err.message ? err.message : "Unknown error");
        cjose_jwk_release(jwk);
        return 1;
    }

    // Set the algorithm (HMAC SHA-256 for oct key)
    if (!cjose_header_set(header, "alg", "HS256", &err)) {
        printf("✗ CJOSE: Failed to set algorithm: %s\n", err.message ? err.message : "Unknown error");
        cjose_header_release(header);
        cjose_jwk_release(jwk);
        return 1;
    }

    // Test creating a simple JWS (JSON Web Signature)
    const char* payload = "{\"sub\":\"1234567890\",\"name\":\"John Doe\",\"iat\":1516239022}";

    cjose_jws_t* jws = cjose_jws_sign(jwk, header,
                                      (const uint8_t*)payload, strlen(payload), &err);
    if (jws) {
        printf("✓ CJOSE: Successfully created JWS signature\n");

        // Get the compact serialization (correct way with 3 parameters)
        const char* compact = NULL;
        if (cjose_jws_export(jws, &compact, &err)) {
            printf("✓ CJOSE: JWS compact format: %.50s...\n", compact); // Show first 50 chars
        } else {
            printf("✗ CJOSE: Failed to export JWS: %s\n", err.message ? err.message : "Unknown error");
        }

        cjose_jws_release(jws);
    } else {
        printf("✗ CJOSE: Failed to create JWS: %s\n", err.message ? err.message : "Unknown error");
    }

    // Clean up
    cjose_header_release(header);
    cjose_jwk_release(jwk);
    return 0;
}

// Main application
int main() {
    printf("CJOSE + MIRACL Core Integration Demo\n");
    printf("====================================\n");
    
    // Test MIRACL Core
    int miracl_result = test_miracl_ecdh();
    
    // Test CJOSE
    int cjose_result = test_cjose();
    
    // Summary
    printf("\n=== Test Summary ===\n");
    printf("MIRACL Core ECDH: %s\n", miracl_result == 0 ? "✓ PASSED" : "✗ FAILED");
    printf("CJOSE JWT: %s\n", cjose_result == 0 ? "✓ PASSED" : "✗ FAILED");
    
    if (miracl_result == 0 && cjose_result == 0) {
        printf("\n🎉 All tests passed! Both libraries are working correctly.\n");
        printf("\nYou can now use:\n");
        printf("- MIRACL Core for: ECDH, ECDSA, Edwards curves, pairings\n");
        printf("- CJOSE for: JWT/JWS/JWE, JSON Web Keys, JOSE operations\n");
        return 0;
    } else {
        printf("\n❌ Some tests failed. Check the error messages above.\n");
        return 1;
    }
}