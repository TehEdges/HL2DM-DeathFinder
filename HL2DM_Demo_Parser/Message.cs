using System;
using HL2DM_Demo_Parser.PacketClasses;

namespace HL2DM_Demo_Parser;

public class Message
{
    public int TickNumber, Length, SequenceIn, SequenceOut, Flags;
    public BitStream MessageData;
    public List<PacketBase> Packets;
    public MessageTypeID MessageType;

    public void ParsePackets(GameState State)
    {
        this.Packets = new();
        bool skipremaining = false;
        while(this.MessageData.BitsLeft > 6 && skipremaining == false)
        {
            //Determine packet type by reading the first 6 bits
            PacketTypeId PacketType = (PacketTypeId)this.MessageData.ReadBits(6, false);
            switch(PacketType)
            {
                case PacketTypeId.serverInfo:
                    serverInfo serverInfoPacket = new(this.MessageData);
                    serverInfoPacket.Process();
                    Packets.Add(serverInfoPacket);
                    break;

                case PacketTypeId.netTick:
                    netTick netTickPacket = new(this.MessageData);
                    netTickPacket.Process();
                    if(State.starttick == 0)
                    {
                        State.starttick = netTickPacket.tick;
                    }
                    State.tick = netTickPacket.tick;
                    Packets.Add(netTickPacket);
                    break;

                case PacketTypeId.setConVar:
                    setConVar setConVarPacket = new(this.MessageData);
                    setConVarPacket.Process();
                    Packets.Add(setConVarPacket);
                    break;
                
                case PacketTypeId.createStringTable:
                    stringTablePackets stringTablePacket = new(this.MessageData, State);
                    stringTablePacket.Process();
                    Packets.Add(stringTablePacket);
                    break;
                
                case PacketTypeId.sigOnState:
                    sigOnState sigOnStatePacket = new(this.MessageData);
                    sigOnStatePacket.Process();
                    Packets.Add(sigOnStatePacket);
                    break;

                case PacketTypeId.setView:
                    setView setViewPacket = new(this.MessageData);
                    setViewPacket.Process();
                    Packets.Add(setViewPacket);
                    break;

                case PacketTypeId.fixAngle:
                    fixAngle fixAnglePacket = new(this.MessageData);
                    fixAnglePacket.Process();
                    Packets.Add(fixAnglePacket);
                    break;
                
                case PacketTypeId.entityMessage:
                    entityMessage entityMessagePacket = new(this.MessageData);
                    entityMessagePacket.Process();
                    Packets.Add(entityMessagePacket);
                    break;
                
                case PacketTypeId.file:
                    fileP filePacket = new(this.MessageData);
                    filePacket.Process();
                    Packets.Add(filePacket);
                    break;

                case PacketTypeId.parseSounds:
                    parseSounds parseSoundsPacket = new(this.MessageData);
                    parseSoundsPacket.Process();
                    Packets.Add(parseSoundsPacket);
                    break;
                
                case PacketTypeId.classInfo:
                    classInfo classInfoPacket = new(this.MessageData);
                    classInfoPacket.Process();
                    Packets.Add(classInfoPacket);
                    break;

                case PacketTypeId.bspDecal:
                    bspDecal bspDecalPacket = new(this.MessageData);
                    bspDecalPacket.Process();
                    Packets.Add(bspDecalPacket);
                    break;

                case PacketTypeId.voiceInit:
                    VoiceInit voiceInitPacket = new(this.MessageData);
                    voiceInitPacket.Process();
                    Packets.Add(voiceInitPacket);
                    break;
                
                case PacketTypeId.voiceData:
                    VoiceData voiceDataPacket = new(this.MessageData);
                    voiceDataPacket.Process();
                    Packets.Add(voiceDataPacket);
                    break;
                
                case PacketTypeId.preFetch:
                    preFetch preFetchPacket = new(this.MessageData);
                    preFetchPacket.Process();
                    Packets.Add(preFetchPacket);
                    break;

                case PacketTypeId.menu:
                    Menu menuPacket = new(this.MessageData);
                    menuPacket.Process();
                    Packets.Add(menuPacket);
                    break;
                
                case PacketTypeId.getCvarValue:
                    getCvarValue getCvarValuePacket = new(this.MessageData);
                    getCvarValuePacket.Process();
                    Packets.Add(getCvarValuePacket);
                    break;

                case PacketTypeId.cmdKeyValues:
                    cmdKeyValues cmdKeyValuesPacket = new(this.MessageData);
                    cmdKeyValuesPacket.Process();
                    Packets.Add(cmdKeyValuesPacket);
                    break;
                
                case PacketTypeId.gameEventList:
                    GameEventList gameEventListPacket = new(this.MessageData, State);
                    gameEventListPacket.Process();
                    Packets.Add(gameEventListPacket);
                    break;
                
                case PacketTypeId.userMessage:
                    UserMessage userMessagePacket = new(this.MessageData, State);
                    userMessagePacket.Process();
                    Packets.Add(userMessagePacket);
                    break;
                
                case PacketTypeId.gameEvent:
                    GameEventPacket gameEventPacket = new(this.MessageData, State);
                    gameEventPacket.Process();
                    Packets.Add(gameEventPacket);
                    break;
                
                case PacketTypeId.updateStringTable:
                    updateStringTable updateStringTablePacket = new(this.MessageData, State);
                    updateStringTablePacket.Process();
                    Packets.Add(updateStringTablePacket);
                    break;

                case PacketTypeId.packetEntities:
                    PacketEntities packetEntitiesPacket = new(this.MessageData);
                    packetEntitiesPacket.Process();
                    Packets.Add(packetEntitiesPacket);
                    break;
                
                case PacketTypeId.tempEntities:
                    tempEntities tempEntitiesPacket = new(this.MessageData);
                    tempEntitiesPacket.Process();
                    Packets.Add(tempEntitiesPacket);
                    break;

                case PacketTypeId.setPause:
                    setPause setPausePacket = new(this.MessageData, State, this.TickNumber);
                    setPausePacket.Process();
                    Packets.Add(setPausePacket);
                    break;

                case PacketTypeId.stringCmd:
                    stringCmd stringCmdPacket = new(this.MessageData);
                    stringCmdPacket.Process();
                    Packets.Add(stringCmdPacket);
                    break;

                case PacketTypeId.unknown:
                    break;

                case PacketTypeId.brokenPacket:
                    skipremaining = true;
                    break;

                default:
                    throw new SystemException($"Unknown Packet Type: {PacketType}");
            }
        }

        //this.Packets.AddRange(Packets);
    }
}
