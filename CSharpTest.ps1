Add-Type -Path .\HL2DM_Demo_Parser\bin\Debug\net8.0\HL2DM_Demo_Parser.dll

$Demo = "C:\users\edge.adm\Downloads\demo.js-master\src\tests\data\hl2dm_ffa.dem"
$Parser = [HL2DM_Demo_Parser.DMParser]::New($Demo)