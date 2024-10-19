Add-Type -Path .\HL2DM_Demo_Parser\bin\Debug\net8.0\HL2DM_Demo_Parser.dll


$Demos = gci "C:\temp\demos"
$outputdir = "C:\temp\csvs"


    foreach($demo in $demos)
    {
        try{
            $Parser = [HL2DM_Demo_Parser.DMParser]::New($demo.FullName)
            $Parser.State.Deaths | Export-Csv -Path ($outputdir + "\" + $demo.Name.Replace(".dem", ".csv"))
        }
        catch
        {

        }
    }

