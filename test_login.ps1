# PowerShell test script for the login API

Write-Host "Testing Login API..." -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green

# Get the client ID from the seeds output
$CLIENT_ID = "-1JitfMw5rV1lhvN6iZIW2ytggVkyvkbONTHqPg6Fc4"

Write-Host "Client ID: $CLIENT_ID`n"

# Test 1: Successful login
Write-Host "Test 1: Successful login" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow
$body1 = @{
    email = "test@example.com"
    password = "password123"
    client_id = $CLIENT_ID
} | ConvertTo-Json

$response1 = Invoke-RestMethod -Uri "http://localhost:3000/api/users/login" -Method Post -Body $body1 -ContentType "application/json"
$response1 | ConvertTo-Json -Depth 10
Write-Host "`n"

# Test 2: Invalid password
Write-Host "Test 2: Invalid password" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow
$body2 = @{
    email = "test@example.com"
    password = "wrongpassword"
    client_id = $CLIENT_ID
} | ConvertTo-Json

try {
    $response2 = Invoke-RestMethod -Uri "http://localhost:3000/api/users/login" -Method Post -Body $body2 -ContentType "application/json" -ErrorAction Stop
    $response2 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Error: $($_.ErrorDetails.Message)`n"
}
Write-Host "`n"

# Test 3: Invalid email format
Write-Host "Test 3: Invalid email format" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow
$body3 = @{
    email = "invalid-email"
    password = "password123"
    client_id = $CLIENT_ID
} | ConvertTo-Json

try {
    $response3 = Invoke-RestMethod -Uri "http://localhost:3000/api/users/login" -Method Post -Body $body3 -ContentType "application/json" -ErrorAction Stop
    $response3 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Error: $($_.ErrorDetails.Message)`n"
}
Write-Host "`n"

# Test 4: Missing email
Write-Host "Test 4: Missing email" -ForegroundColor Yellow
Write-Host "---------------------" -ForegroundColor Yellow
$body4 = @{
    password = "password123"
    client_id = $CLIENT_ID
} | ConvertTo-Json

try {
    $response4 = Invoke-RestMethod -Uri "http://localhost:3000/api/users/login" -Method Post -Body $body4 -ContentType "application/json" -ErrorAction Stop
    $response4 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Error: $($_.ErrorDetails.Message)`n"
}
Write-Host "`n"

# Test 5: Invalid client ID
Write-Host "Test 5: Invalid client ID" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Yellow
$body5 = @{
    email = "test@example.com"
    password = "password123"
    client_id = "invalid_client_id"
} | ConvertTo-Json

try {
    $response5 = Invoke-RestMethod -Uri "http://localhost:3000/api/users/login" -Method Post -Body $body5 -ContentType "application/json" -ErrorAction Stop
    $response5 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Error: $($_.ErrorDetails.Message)`n"
}