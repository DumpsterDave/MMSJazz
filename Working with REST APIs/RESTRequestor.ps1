$data = @{Name="Scott Corio"; Message="Hello"; Number=5};
$json = ConvertTo-Json $data
Invoke-RestMethod -uri http://localhost:8001 -Method Put -Body $json -ContentType 'application/json'