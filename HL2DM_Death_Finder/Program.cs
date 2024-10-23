using System.Diagnostics;
using HL2DM_Demo_Parser;
using HL2DM_Demo_Parser.PacketClasses;



if (args.Length != 2)
{
    Console.WriteLine("Please ensure you are providing only two arguments.\n\t1. Directory Path for demos folder. \n\t2. Directory Path for csv output.");
}
else
{
    string demospath = args[0];
    string cvspath = args[1];

    DirectoryInfo demos = new(demospath);
    foreach(FileInfo file in demos.GetFiles())
    {
        Console.WriteLine($"{file.FullName}");
        string csvName = file.Name.Replace(".dem", ".csv");
        StreamWriter csvWriter = new(cvspath + "\\" + csvName);
        HL2DM_Demo_Parser.DMParser Parser = new DMParser(file.FullName);
        csvWriter.WriteLine("Attacker, Victicm, Weapon, Headshot, Tick");
        foreach(DeathEvent death in Parser.State.Deaths)
        {
            string Line = $"{death.attacker}, {death.victim}, {death.weapon}, {death.headshot}, {death.tick}";
            csvWriter.WriteLine(Line);
        }
        csvWriter.WriteLine("");
        csvWriter.WriteLine("Kind, From, Text");
        foreach(SayText2Msg msg in Parser.State.Chat)
        {
            string msgtext = $"{msg.kind}, {msg.from}, {msg.text}";
            csvWriter.WriteLine(msgtext);
        }
    }
}

//HL2DM_Demo_Parser.DMParser parser = new DMParser("C:\\temp\\demos\\2024-03-06_03-32-17_dm_lostvillage_r1_2v2.dem");