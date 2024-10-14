using System;

namespace HL2DM_Demo_Parser;

public enum PacketTypeId {
    unknown = 0,
	file = 2,
	netTick = 3,
	stringCmd = 4,
	setConVar = 5,
	sigOnState = 6,
	print = 7,
	serverInfo = 8,
	classInfo = 10,
	setPause = 11,
	createStringTable = 12,
	updateStringTable = 13,
	voiceInit = 14,
	voiceData = 15,
	parseSounds = 17,
	setView = 18,
	fixAngle = 19,
	bspDecal = 21,
	userMessage = 23,
	entityMessage = 24,
	gameEvent = 25,
	packetEntities = 26,
	tempEntities = 27,
	preFetch = 28,
	menu = 29,
	gameEventList = 30,
	getCvarValue = 31,
	cmdKeyValues = 32
}

public abstract class PacketBase
{
    public BitStream MessageData;
    public abstract void Process();
}

public class serverInfo : PacketBase
{
    public int Version { get; set; }
    public int ServerCount { get; set; }
    public bool Stv { get; set; }
    public bool Dedicated { get; set; }
    public int MaxCrc { get; set; }
    public int MaxClasses { get; set; }
    public int MapHash { get; set; }
    public int PlayerCount { get; set; }
    public int MaxPlayerCount { get; set; }
    public float IntervalPerTick { get; set; }
    public string Platform { get; set; }
    public string Game { get; set; }
    public string Map { get; set; }
    public string Skybox { get; set; }
    public string ServerName { get; set; }
    public bool Replay { get; set; }

    public serverInfo(BitStream stream)
    {
        this.MessageData = stream;
    }
    public override void Process()
    {
        this.Version = this.MessageData.ReadBits(16, true);
        this.ServerCount = this.MessageData.ReadBits(32, true);
        this.Stv = this.MessageData.ReadBoolean();
        this.Dedicated = this.MessageData.ReadBoolean();
        this.MaxCrc = this.MessageData.ReadBits(32, true);
        this.MaxClasses = this.MessageData.ReadBits(16, true);
        this.MapHash = this.MessageData.ReadBits(128, true);
        this.PlayerCount = this.MessageData.ReadBits(8, true);
        this.MaxPlayerCount = this.MessageData.ReadBits(8, true);
        this.Platform = this.MessageData.ReadASCIIString(1);
        this.Game = this.MessageData.ReadUTF8String(0);
        this.Map = this.MessageData.ReadUTF8String(0);
        this.Skybox = this.MessageData.ReadUTF8String(0);
        this.ServerName = this.MessageData.ReadUTF8String(0);
        this.Replay = this.MessageData.ReadBoolean();
    }
}

public class Property
{
    public string Name { get; set; }
    public string Type { get; set; }
}
