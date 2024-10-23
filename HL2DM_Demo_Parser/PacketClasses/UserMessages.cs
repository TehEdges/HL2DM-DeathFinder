using System;

namespace HL2DM_Demo_Parser.PacketClasses;

public enum UserMessageType {
	Unknown = -1,
	Geiger = 0,
	Train = 1,
	HudText = 2,
	SayText = 3,
	SayText2 = 4,
	TextMsg = 5,
	ResetHUD = 6,
	GameTitle = 7,
	ItemPickup = 8,
	ShowMenu = 9,
	Shake = 10,
	Fade = 11,
	VGUIMenu = 12,
	Rumble = 13,
	CloseCaption = 14,
	SendAudio = 15,
	VoiceMask = 16,
	RequestState = 17,
	Damage = 18,
	HintText = 19,
	KeyHintText = 20,
	HudMsg = 21,
	AmmoDenied = 22,
	AchievementEvent = 23,
	UpdateRadar = 24,
	VoiceSubtitle = 25,
	HudNotify = 26,
	HudNotifyCustom = 27,
	PlayerStatsUpdate = 28,
	PlayerIgnited = 29,
	PlayerIgnitedInv = 30,
	HudArenaNotify = 31,
	UpdateAchievement = 32,
	TrainingMsg = 33,
	TrainingObjective = 34,
	DamageDodged = 35,
	PlayerJarated = 36,
	PlayerExtinguished = 37,
	PlayerJaratedFade = 38,
	PlayerShieldBlocked = 39,
	BreakModel = 40,
	CheapBreakModel = 41,
	BreakModel_Pumpkin = 42,
	BreakModelRocketDud = 43,
	CallVoteFailed = 44,
	VoteStart = 45,
	VotePass = 46,
	VoteFailed = 47,
	VoteSetup = 48,
	PlayerBonusPoints = 49,
	SpawnFlyingBird = 50,
	PlayerGodRayEffect = 51,
	SPHapWeapEvent = 52,
	HapDmg = 53,
	HapPunch = 54,
	HapSetDrag = 55,
	HapSet = 56,
	HapMeleeContact = 57
}
public class UserMessage    :   PacketBase
{
    public UserMessageType msgType;
    public int length;
    public BitStream usrmsgData;
    public object[] Message;
    public GameState state;
    public UserMessage(BitStream stream, GameState state)    :   base(stream)
    {
        this.state = state;
    }

    public override void Process()
    {
        this.msgType = (UserMessageType)this.MessageData.ReadUint8();
        this.length = this.MessageData.ReadBits(11, false);
        this.usrmsgData = this.MessageData.ReadBitStream(length); 

        //object[] usrMsgPacket = new object[] {msgType, length, usrmsgData};
        this.state.UserMessages.Add(this);
    }
}


public class SayText2Msg	: PacketBase
{
	public int client, raw, pos;
	public  string from, text, kind;
	public SayText2Msg(BitStream stream) : base(stream)
	{}
    public override void Process()
    {
		this.client = this.MessageData.ReadUint8();
		this.raw = this.MessageData.ReadUint8();
		this.pos = this.MessageData.Index;
        if(this.MessageData.ReadUint8() == 1)
		{
			int first = this.MessageData.ReadUint8();
			if(first == 7)
			{
				string color = this.MessageData.ReadUTF8String(6);
			}
			else
			{
				this.MessageData._index = this.pos + 8;
			}
			this.text = this.MessageData.ReadUTF8String(0);
			if(this.text.Substring(0, 6) == "*DEAD*")
			{
				int start = this.text.IndexOf("\u0003");
				int end = this.text.IndexOf("\u0001");
				this.from = this.text.Substring(start + 1, end - start - 1);
				this.text = this.text.Substring(end + 5);
				this.kind = "HL2MP_Chat_AllDead";
			}
		}
		else
		{
			this.MessageData.Index = this.pos;
			this.kind = this.MessageData.ReadUTF8String(0);
			this.from = this.MessageData.ReadUTF8String(0);
			this.text = this.MessageData.ReadUTF8String(0);
			//Null bytes at the end of the text stream
			this.MessageData.ReadUint16();
		}

		this.text = this.text.Replace("\u0001", "");
		this.text = this.text.Replace("\u0003", "");
		int stringpos = this.text.IndexOf("\u0007");
    }

}