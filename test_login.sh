#!/bin/bash
# Quick test script for the login API

echo "Testing Login API..."
echo "===================="

# Get the client ID from the seeds output
CLIENT_ID="-1JitfMw5rV1lhvN6iZIW2ytggVkyvkbONTHqPg6Fc4"

echo "Client ID: $CLIENT_ID"
echo ""

# Test 1: Successful login
echo "Test 1: Successful login"
echo "------------------------"
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "client_id": "'"$CLIENT_ID"'"
  }' 2>/dev/null | python -m json.tool
echo ""
echo ""

# Test 2: Invalid password
echo "Test 2: Invalid password"
echo "------------------------"
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "wrongpassword",
    "client_id": "'"$CLIENT_ID"'"
  }' 2>/dev/null | python -m json.tool
echo ""
echo ""

# Test 3: Invalid email format
echo "Test 3: Invalid email format"
echo "----------------------------"
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "invalid-email",
    "password": "password123",
    "client_id": "'"$CLIENT_ID"'"
  }' 2>/dev/null | python -m json.tool
echo ""
echo ""

# Test 4: Missing email
echo "Test 4: Missing email"
echo "---------------------"
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "password": "password123",
    "client_id": "'"$CLIENT_ID"'"
  }' 2>/dev/null | python -m json.tool
echo ""
echo ""

# Test 5: Invalid client ID
echo "Test 5: Invalid client ID"
echo "-------------------------"
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "client_id": "invalid_client_id"
  }' 2>/dev/null | python -m json.tool