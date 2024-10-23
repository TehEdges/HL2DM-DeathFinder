using System;
using HL2DM_Demo_Parser.PacketClasses;

namespace HL2DM_Demo_Parser;

public class GameState
{
    public int Version, tick, starttick, tickoffset, pausestarttick;
    public List<StringTable> stringTables;
    public Dictionary<int, object[]> GameEventList;
    public List<UserMessage> UserMessages;
    public List<GameEvent> Events;
    public List<UserInfo> userInfo = new();
    public List<DeathEvent> Deaths = new();
    public List<SayText2Msg>Chat = new();

    public void ProcessStringTables(StringTable Table)
    {
        switch(Table.TableName)
        {
            case "userinfo":
                foreach(StringTableEntry Entry in Table.Entries)
                {
                    CalculateUserInfoFromEntry(Entry.text, Entry.extraData);
                }
                break;
        }
    }

    public void ProcessPlayerDeaths(GameEvent Event)
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
            if((int)attackerid != 0)
            {
                UserInfo attacker = this.userInfo.FirstOrDefault(u => u.UserId == (int)attackerid);
                deathEvent.attacker = attacker.Name.Replace("\0", "");
            }
            else
            {
                deathEvent.attacker = "Environment";
            }                
            deathEvent.weapon = (string)weapon;
            deathEvent.headshot = (bool)headshot;
            deathEvent.tick = (int)tick - this.starttick;
            this.Deaths.Add(deathEvent);
        }
    }

    public void UseBaseGameState()
    {
        string jsonbasestate = "{\"0\":[0,\"server_spawn\",[{\"Name\":\"hostname\",\"Type\":1},{\"Name\":\"address\",\"Type\":1},{\"Name\":\"ip\",\"Type\":3},{\"Name\":\"port\",\"Type\":4},{\"Name\":\"game\",\"Type\":1},{\"Name\":\"mapname\",\"Type\":1},{\"Name\":\"maxplayers\",\"Type\":3},{\"Name\":\"os\",\"Type\":1},{\"Name\":\"dedicated\",\"Type\":6},{\"Name\":\"password\",\"Type\":6}]],\"1\":[1,\"server_changelevel_failed\",[{\"Name\":\"levelname\",\"Type\":1}]],\"2\":[2,\"server_shutdown\",[{\"Name\":\"reason\",\"Type\":1}]],\"3\":[3,\"server_cvar\",[{\"Name\":\"cvarname\",\"Type\":1},{\"Name\":\"cvarvalue\",\"Type\":1}]],\"4\":[4,\"server_message\",[{\"Name\":\"text\",\"Type\":1}]],\"5\":[5,\"server_addban\",[{\"Name\":\"name\",\"Type\":1},{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"networkid\",\"Type\":1},{\"Name\":\"ip\",\"Type\":1},{\"Name\":\"duration\",\"Type\":1},{\"Name\":\"by\",\"Type\":1},{\"Name\":\"kicked\",\"Type\":6}]],\"6\":[6,\"server_removeban\",[{\"Name\":\"networkid\",\"Type\":1},{\"Name\":\"ip\",\"Type\":1},{\"Name\":\"by\",\"Type\":1}]],\"7\":[7,\"player_connect\",[{\"Name\":\"name\",\"Type\":1},{\"Name\":\"index\",\"Type\":5},{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"networkid\",\"Type\":1},{\"Name\":\"address\",\"Type\":1},{\"Name\":\"bot\",\"Type\":4}]],\"8\":[8,\"player_connect_client\",[{\"Name\":\"name\",\"Type\":1},{\"Name\":\"index\",\"Type\":5},{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"networkid\",\"Type\":1},{\"Name\":\"bot\",\"Type\":4}]],\"9\":[9,\"player_info\",[{\"Name\":\"name\",\"Type\":1},{\"Name\":\"index\",\"Type\":5},{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"networkid\",\"Type\":1},{\"Name\":\"bot\",\"Type\":6}]],\"10\":[10,\"player_disconnect\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"reason\",\"Type\":1},{\"Name\":\"name\",\"Type\":1},{\"Name\":\"networkid\",\"Type\":1},{\"Name\":\"bot\",\"Type\":4}]],\"11\":[11,\"player_activate\",[{\"Name\":\"userid\",\"Type\":4}]],\"12\":[12,\"player_say\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"text\",\"Type\":1}]],\"13\":[13,\"client_disconnect\",[{\"Name\":\"message\",\"Type\":1}]],\"14\":[14,\"client_beginconnect\",[{\"Name\":\"address\",\"Type\":1},{\"Name\":\"ip\",\"Type\":3},{\"Name\":\"port\",\"Type\":4},{\"Name\":\"source\",\"Type\":1}]],\"15\":[15,\"client_connected\",[{\"Name\":\"address\",\"Type\":1},{\"Name\":\"ip\",\"Type\":3},{\"Name\":\"port\",\"Type\":4}]],\"16\":[16,\"client_fullconnect\",[{\"Name\":\"address\",\"Type\":1},{\"Name\":\"ip\",\"Type\":3},{\"Name\":\"port\",\"Type\":4}]],\"17\":[17,\"host_quit\",[]],\"18\":[18,\"team_info\",[{\"Name\":\"teamid\",\"Type\":5},{\"Name\":\"teamname\",\"Type\":1}]],\"19\":[19,\"team_score\",[{\"Name\":\"teamid\",\"Type\":5},{\"Name\":\"score\",\"Type\":4}]],\"20\":[20,\"teamplay_broadcast_audio\",[{\"Name\":\"team\",\"Type\":5},{\"Name\":\"sound\",\"Type\":1}]],\"21\":[21,\"player_team\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"team\",\"Type\":5},{\"Name\":\"oldteam\",\"Type\":5},{\"Name\":\"disconnect\",\"Type\":6},{\"Name\":\"autoteam\",\"Type\":6},{\"Name\":\"silent\",\"Type\":6},{\"Name\":\"name\",\"Type\":1}]],\"22\":[22,\"player_class\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"class\",\"Type\":1}]],\"23\":[23,\"player_death\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"attacker\",\"Type\":4},{\"Name\":\"weapon\",\"Type\":1},{\"Name\":\"headshot\",\"Type\":6}]],\"24\":[24,\"player_hurt\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"attacker\",\"Type\":4},{\"Name\":\"health\",\"Type\":5}]],\"25\":[25,\"player_chat\",[{\"Name\":\"teamonly\",\"Type\":6},{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"text\",\"Type\":1}]],\"26\":[26,\"player_score\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"kills\",\"Type\":4},{\"Name\":\"deaths\",\"Type\":4},{\"Name\":\"score\",\"Type\":4}]],\"27\":[27,\"player_spawn\",[{\"Name\":\"userid\",\"Type\":4}]],\"28\":[28,\"player_shoot\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"weapon\",\"Type\":5},{\"Name\":\"mode\",\"Type\":5}]],\"29\":[29,\"player_use\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"entity\",\"Type\":4}]],\"30\":[30,\"player_changename\",[{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"oldname\",\"Type\":1},{\"Name\":\"newname\",\"Type\":1}]],\"31\":[31,\"player_hintmessage\",[{\"Name\":\"hintmessage\",\"Type\":1}]],\"32\":[32,\"base_player_teleported\",[{\"Name\":\"entindex\",\"Type\":4}]],\"33\":[33,\"game_init\",[]],\"34\":[34,\"game_newmap\",[{\"Name\":\"mapname\",\"Type\":1}]],\"35\":[35,\"game_start\",[{\"Name\":\"roundslimit\",\"Type\":3},{\"Name\":\"timelimit\",\"Type\":3},{\"Name\":\"fraglimit\",\"Type\":3},{\"Name\":\"objective\",\"Type\":1}]],\"36\":[36,\"game_end\",[{\"Name\":\"winner\",\"Type\":5}]],\"37\":[37,\"round_start\",[{\"Name\":\"timelimit\",\"Type\":3},{\"Name\":\"fraglimit\",\"Type\":3},{\"Name\":\"objective\",\"Type\":1}]],\"38\":[38,\"round_end\",[{\"Name\":\"winner\",\"Type\":5},{\"Name\":\"reason\",\"Type\":5},{\"Name\":\"message\",\"Type\":1}]],\"39\":[39,\"game_message\",[{\"Name\":\"target\",\"Type\":5},{\"Name\":\"text\",\"Type\":1}]],\"40\":[40,\"break_breakable\",[{\"Name\":\"entindex\",\"Type\":3},{\"Name\":\"userid\",\"Type\":4},{\"Name\":\"material\",\"Type\":5}]],\"41\":[41,\"break_prop\",[{\"Name\":\"entindex\",\"Type\":3},{\"Name\":\"userid\",\"Type\":4}]],\"42\":[42,\"entity_killed\",[{\"Name\":\"entindex_killed\",\"Type\":3},{\"Name\":\"entindex_attacker\",\"Type\":3},{\"Name\":\"entindex_inflictor\",\"Type\":3},{\"Name\":\"damagebits\",\"Type\":3}]],\"43\":[43,\"bonus_updated\",[{\"Name\":\"numadvanced\",\"Type\":4},{\"Name\":\"numbronze\",\"Type\":4},{\"Name\":\"numsilver\",\"Type\":4},{\"Name\":\"numgold\",\"Type\":4}]],\"44\":[44,\"achievement_event\",[{\"Name\":\"achievement_name\",\"Type\":1},{\"Name\":\"cur_val\",\"Type\":4},{\"Name\":\"max_val\",\"Type\":4}]],\"45\":[45,\"achievement_increment\",[{\"Name\":\"achievement_id\",\"Type\":3},{\"Name\":\"cur_val\",\"Type\":4},{\"Name\":\"max_val\",\"Type\":4}]],\"46\":[46,\"physgun_pickup\",[{\"Name\":\"entindex\",\"Type\":3}]],\"47\":[47,\"flare_ignite_npc\",[{\"Name\":\"entindex\",\"Type\":3}]],\"48\":[48,\"helicopter_grenade_punt_miss\",[]],\"49\":[49,\"user_data_downloaded\",[]],\"50\":[50,\"ragdoll_dissolved\",[{\"Name\":\"entindex\",\"Type\":3}]],\"51\":[51,\"hltv_changed_mode\",[{\"Name\":\"oldmode\",\"Type\":4},{\"Name\":\"newmode\",\"Type\":4},{\"Name\":\"obs_target\",\"Type\":4}]],\"52\":[52,\"hltv_changed_target\",[{\"Name\":\"mode\",\"Type\":4},{\"Name\":\"old_target\",\"Type\":4},{\"Name\":\"obs_target\",\"Type\":4}]],\"53\":[53,\"vote_ended\",[]],\"54\":[54,\"vote_started\",[{\"Name\":\"issue\",\"Type\":1},{\"Name\":\"param1\",\"Type\":1},{\"Name\":\"team\",\"Type\":5},{\"Name\":\"initiator\",\"Type\":3}]],\"55\":[55,\"vote_changed\",[{\"Name\":\"vote_option1\",\"Type\":5},{\"Name\":\"vote_option2\",\"Type\":5},{\"Name\":\"vote_option3\",\"Type\":5},{\"Name\":\"vote_option4\",\"Type\":5},{\"Name\":\"vote_option5\",\"Type\":5},{\"Name\":\"potentialVotes\",\"Type\":5}]],\"56\":[56,\"vote_passed\",[{\"Name\":\"details\",\"Type\":1},{\"Name\":\"param1\",\"Type\":1},{\"Name\":\"team\",\"Type\":5}]],\"57\":[57,\"vote_failed\",[{\"Name\":\"team\",\"Type\":5}]],\"58\":[58,\"vote_cast\",[{\"Name\":\"vote_option\",\"Type\":5},{\"Name\":\"team\",\"Type\":4},{\"Name\":\"entityid\",\"Type\":3}]],\"59\":[59,\"vote_options\",[{\"Name\":\"count\",\"Type\":5},{\"Name\":\"option1\",\"Type\":1},{\"Name\":\"option2\",\"Type\":1},{\"Name\":\"option3\",\"Type\":1},{\"Name\":\"option4\",\"Type\":1},{\"Name\":\"option5\",\"Type\":1}]],\"60\":[60,\"replay_saved\",[]],\"61\":[61,\"entered_performance_mode\",[]],\"62\":[62,\"browse_replays\",[]],\"63\":[63,\"replay_youtube_stats\",[{\"Name\":\"views\",\"Type\":3},{\"Name\":\"likes\",\"Type\":3},{\"Name\":\"favorited\",\"Type\":3}]],\"64\":[64,\"inventory_updated\",[]],\"65\":[65,\"cart_updated\",[]],\"66\":[66,\"store_pricesheet_updated\",[]],\"67\":[67,\"gc_connected\",[]],\"68\":[68,\"item_schema_initialized\",[]],\"69\":[69,\"teamplay_round_start\",[{\"Name\":\"full_reset\",\"Type\":6}]],\"70\":[70,\"spec_target_updated\",[]],\"71\":[71,\"achievement_earned\",[{\"Name\":\"player\",\"Type\":5},{\"Name\":\"achievement\",\"Type\":4}]],\"72\":[72,\"hltv_status\",[{\"Name\":\"clients\",\"Type\":3},{\"Name\":\"slots\",\"Type\":3},{\"Name\":\"proxies\",\"Type\":4},{\"Name\":\"master\",\"Type\":1}]],\"73\":[73,\"hltv_cameraman\",[{\"Name\":\"index\",\"Type\":4}]],\"74\":[74,\"hltv_rank_camera\",[{\"Name\":\"index\",\"Type\":5},{\"Name\":\"rank\",\"Type\":2},{\"Name\":\"target\",\"Type\":4}]],\"75\":[75,\"hltv_rank_entity\",[{\"Name\":\"index\",\"Type\":4},{\"Name\":\"rank\",\"Type\":2},{\"Name\":\"target\",\"Type\":4}]],\"76\":[76,\"hltv_fixed\",[{\"Name\":\"posx\",\"Type\":3},{\"Name\":\"posy\",\"Type\":3},{\"Name\":\"posz\",\"Type\":3},{\"Name\":\"theta\",\"Type\":4},{\"Name\":\"phi\",\"Type\":4},{\"Name\":\"offset\",\"Type\":4},{\"Name\":\"fov\",\"Type\":2},{\"Name\":\"target\",\"Type\":4}]],\"77\":[77,\"hltv_chase\",[{\"Name\":\"target1\",\"Type\":4},{\"Name\":\"target2\",\"Type\":4},{\"Name\":\"distance\",\"Type\":4},{\"Name\":\"theta\",\"Type\":4},{\"Name\":\"phi\",\"Type\":4},{\"Name\":\"inertia\",\"Type\":5},{\"Name\":\"ineye\",\"Type\":5}]],\"78\":[78,\"hltv_message\",[{\"Name\":\"text\",\"Type\":1}]],\"79\":[79,\"hltv_title\",[{\"Name\":\"text\",\"Type\":1}]],\"80\":[80,\"hltv_chat\",[{\"Name\":\"text\",\"Type\":1}]]}";
        var dictionary = System.Text.Json.JsonSerializer.Deserialize<Dictionary<int, object[]>>(jsonbasestate);
        for(int i = 0; i < dictionary.Count; i++)
        {
            int id = i;

            int sid = System.Text.Json.JsonSerializer.Deserialize<int>(((System.Text.Json.JsonElement)dictionary[i][0]).GetRawText());
            string name = System.Text.Json.JsonSerializer.Deserialize<string>(((System.Text.Json.JsonElement)dictionary[i][1]).GetRawText());
            var Events = System.Text.Json.JsonSerializer.Deserialize<List<GameEventEntryDefiition>>(((System.Text.Json.JsonElement)dictionary[i][2]).GetRawText()); 
            object[] evententry = new object[] {sid, name, Events};
            this.GameEventList.Add(id, evententry);
        }
        //this.GameEventList = dictionary;
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

