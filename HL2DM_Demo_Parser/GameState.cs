using System;

namespace HL2DM_Demo_Parser;

public class GameState
{
    public int Version, tick, starttick;
    public List<StringTable> stringTables;
    public Dictionary<int, object[]> GameEventList;
    public List<object[]> UserMessages;

}


