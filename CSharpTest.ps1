Add-Type -Path .\HL2DM_Demo_Parser\bin\Debug\net8.0\HL2DM_Demo_Parser.dll

$Demo = ".\DemoTester\demos\2024-04-06_16-51-49_dm_octagon_sf_b4_2v2.dem"
$Parser = [HL2DM_Demo_Parser.DMParser]::New($Demo)
