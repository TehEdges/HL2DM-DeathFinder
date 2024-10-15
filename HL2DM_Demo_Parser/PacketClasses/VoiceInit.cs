using System;

namespace HL2DM_Demo_Parser.PacketClasses;

public class VoiceInit  : PacketBase
{
    string codec;
    int quality, extraData;

    public VoiceInit(BitStream stream)  : base(stream)
    {}
    public override void Process()
    {
        this.codec = this.MessageData.ReadASCIIString(0);
        this.quality = this.MessageData.ReadUint8();
        this.extraData = this.readExtraData();
    }

    private int readExtraData()
    {
        if(this.quality == 255)
        {
            return this.MessageData.ReadUint16();
        }
        else if (this.codec == "vaudio_celt")
        {
            return 11025;
        }
        else
        {
            return 0;
        }
    }
}
