using System;

namespace HL2DM_Demo_Parser;

public class DemoHeader
{
    public string  filestamp, servername, clientname, mapname, gamedirectory;
    public int    demoprotocol, networkprotocol, tickcount, framecount, signonlength;
    public float playbacktime;

    public DemoHeader(BitStream stream)
    {
        this.filestamp = stream.ReadASCIIString(8);
        this.demoprotocol = stream.ReadInt32();
        this.networkprotocol = stream.ReadInt32();
        this.servername = stream.ReadASCIIString(260);
        this.clientname = stream.ReadASCIIString(260);
        this.mapname = stream.ReadASCIIString(260);
        this.gamedirectory = stream.ReadASCIIString(260);
        this.playbacktime = stream.ReadFloat32();
        this.tickcount = stream.ReadInt32();
        this.framecount = stream.ReadInt32();
        this.signonlength = stream.ReadInt32();
    }
}
