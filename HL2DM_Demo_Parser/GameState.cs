using System;
using HL2DM_Demo_Parser.PacketClasses;

namespace HL2DM_Demo_Parser;

public class GameState
{
    public int Version, tick, starttick;
    public List<StringTable> stringTables;
    public Dictionary<int, object[]> GameEventList;
    public List<object[]> UserMessages;
    public List<GameEvent> Events;
    public List<UserInfo> userInfo = new();
    public List<DeathEvent> Deaths = new();

    public void ProcessStringTables()
    {
        StringTable userInfoTable = stringTables.FirstOrDefault(table => table.TableName == "userinfo");
        if(userInfoTable != null)
        {
            foreach(StringTableEntry Entry in userInfoTable.Entries)
            {
                CalculateUserInfoFromEntry(Entry.text, Entry.extraData);
            }
        }
    }

    public void ProcessPlayerDeaths()
    {
        foreach(GameEvent Event in this.Events)
        {
            if(Event.GameEventType == GameEventTypes.player_death)
            {
                DeathEvent deathEvent = new();
                Event.Values.TryGetValue("userid", out object victimid);
                Event.Values.TryGetValue("attacker", out object attackerid);
                Event.Values.TryGetValue("weapon", out object weapon);
                Event.Values.TryGetValue("headshot", out object headshot);
                Event.Values.TryGetValue("tick", out object tick);
                UserInfo victim = this.userInfo.FirstOrDefault(u => u.UserId == (int)victimid);
                deathEvent.victim = victim.Name.Replace("\0", "");
                UserInfo attacker = this.userInfo.FirstOrDefault(u => u.UserId == (int)attackerid);
                deathEvent.attacker = attacker.Name.Replace("\0", "");
                deathEvent.weapon = (string)weapon;
                deathEvent.headshot = (bool)headshot;
                deathEvent.tick = (int)tick - this.starttick;
                this.Deaths.Add(deathEvent);
            }
        }
    }

    private void CalculateUserInfoFromEntry(string entryName, BitStream extraData)
    {
        if(extraData != null)
        {
            if (extraData.BitsLeft > (32 * 8))
            {
                // Reading the name from the BitStream
                string name = extraData.ReadUTF8String(32);
                
                // Reading the userId from the BitStream
                uint userId = extraData.ReadUint32();

                // Ensuring userId is <= 256
                while (userId > 256)
                {
                    userId -= 256;
                }

                // Reading steamId from the BitStream
                string steamId = extraData.ReadUTF8String(0);

                if (!string.IsNullOrEmpty(steamId))
                {
                    // Parsing entryName as an integer and incrementing
                    int entityId = int.Parse(entryName) + 1;

                    // Finding the user in the userInfo list
                    var user = this.userInfo.FirstOrDefault(u => u.UserId == userId);

                    if (user == null)
                    {
                        // Adding new user to the userInfo list
                        var newUser = new UserInfo
                        {
                            Name = name,
                            UserId = userId,
                            SteamId = steamId,
                            EntityId = entityId
                        };

                        this.userInfo.Add(newUser);
                    }
                    else
                    {
                        // Updating existing user's name and steamId
                        user.Name = name;
                        user.SteamId = steamId;
                    }
                }
            }
        }
    }

}

public class UserInfo
{
    public string Name { get; set; }
    public uint UserId { get; set; }
    public string SteamId { get; set; }
    public int EntityId { get; set; }
}

public class DeathEvent
{
    public string attacker, victim, weapon;
    public int tick;
    public bool headshot;
}

