using System;
using System.Diagnostics;
using System.Numerics;

namespace HL2DM_Demo_Parser;

public class bspDecal : PacketBase
{
    public int modelIndex, entIndex, textureIndex;
    public Vector3 position;
    public bool lowPriority;
    private Vector3 getVecCoord()
    {
        bool hasX = this.MessageData.ReadBoolean();
        bool hasY = this.MessageData.ReadBoolean();
        bool hasZ = this.MessageData.ReadBoolean();

        var x = hasX ? this.MessageData.ReadBitCoord(this.MessageData) : 0;
        var y = hasY ? this.MessageData.ReadBitCoord(this.MessageData) : 0;
        var z = hasZ ? this.MessageData.ReadBitCoord(this.MessageData) : 0;

        Vector3 vec = new((float)x, (float)y, (float)z);
        return vec;
    }
    public bspDecal(BitStream stream)   :   base(stream)
    {}

    public override void Process()
    {
        this.modelIndex = 0;
        this.entIndex = 0;
        this.position = this.getVecCoord();
        this.textureIndex = this.MessageData.ReadBits(9, false);
        if(this.MessageData.ReadBoolean())
        {
            this.entIndex = this.MessageData.ReadBits(11, false);
            this.modelIndex = this.MessageData.ReadBits(12, false);
        }
        this.lowPriority = this.MessageData.ReadBoolean();
    }
}
