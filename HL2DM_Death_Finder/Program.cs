using System.Diagnostics;
using HL2DM_Demo_Parser;
using HL2DM_Demo_Parser.PacketClasses;



if (args.Length != 3)
{
    Console.WriteLine("Please ensure you are providing only three arguments.\n\t1. Directory Path for demos folder. \n\t2. Directory Path for csv output.\n\t3. true to save the chat, false to not save the chat.");
}
else
{
    string demospath = args[0];
    string cvspath = args[1];
    bool savechat;
    //Validate all of our arguments
    if (!bool.TryParse(args[2], out savechat))
    {
        Console.WriteLine("Invalid value for savechat. Please use 'true' or 'false'.");
        return;
    }
    if (!Directory.Exists(demospath))
    {
        Console.WriteLine($"Demos directory does not exist: {demospath}");
        return;
    }

    if (!Directory.Exists(cvspath))
    {
        Console.WriteLine($"CSV output directory does not exist: {cvspath}");
        return;
    }

    DirectoryInfo demos = new(demospath);
    foreach(FileInfo file in demos.GetFiles())
    {
        Console.WriteLine($"{file.FullName}");
        string csvName = file.Name.Replace(".dem", ".csv");
        StreamWriter csvWriter = new(cvspath + "\\" + csvName);
        HL2DM_Demo_Parser.DMParser Parser = new DMParser(file.FullName);
        csvWriter.WriteLine("AttackerSteamID, Attacker, VictimSteamID, Victim, Weapon, Headshot, Tick");
        foreach(DeathEvent death in Parser.State.Deaths)
        {
            string Line = $"{death.attackersteamid}, {death.attacker}, {death.victimsteamid}, {death.victim}, {death.weapon}, {death.headshot}, {death.tick}";
            csvWriter.WriteLine(Line);
        }
        if (savechat)
        {
            csvWriter.WriteLine("");
            csvWriter.WriteLine("Kind, From, Text");
            foreach (SayText2Msg msg in Parser.State.Chat)
            {
                string msgtext = $"{msg.kind}, {msg.from}, {msg.text}";
                csvWriter.WriteLine(msgtext);
            }
        }
        csvWriter.Flush();
        csvWriter.Close();
    }
}

//HL2DM_Demo_Parser.DMParser parser = new DMParser("C:\\temp\\demos\\2024-03-06_03-32-17_dm_lostvillage_r1_2v2.dem");