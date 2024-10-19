using System.Diagnostics;
using HL2DM_Demo_Parser;

DirectoryInfo demos = new("C:\\temp\\demos");
foreach(FileInfo file in demos.GetFiles())
{
    Console.WriteLine($"{file.FullName}");
    HL2DM_Demo_Parser.DMParser Parser = new DMParser(file.FullName);
}