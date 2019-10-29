$data = @{Name="Scott Corio"; Message="Hello"; Number=Get-Random};
$json = ConvertTo-Json $data
Invoke-RestMethod -uri http://localhost:8001 -Method Put -Body $json -ContentType 'application/json'