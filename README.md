# HL2DM Death Finder

**HL2DM Death Finder** is a C# program designed to parse `.dem` files from *Half-Life 2: Deathmatch* (HL2DM), extracting player death events and chat messages and saving the results in structured CSV files.

## Features
- **Death Event Extraction**: Captures information about player deaths, including attacker, victim, weapon, headshot status, and game tick.
- **Chat Message Extraction**: Extracts chat messages with details such as type, sender, and message content.

## Runtime Requirements
- **Requirement**: .NET 8.0 Runtime or later

## Usage
The program takes two arguments:
1. **Input Directory**: Directory containing the `.dem` files.
2. **Output Directory**: Directory where the parsed CSV files will be saved.
3. **Save Chat**: True to save the chat to the csv, false to not save the chat.

Each generated CSV file includes two sections: **Deaths** and **Chat**.

### CSV File Structure

**Deaths Section**  
| Attacker | Victim | Weapon | Headshot | Tick |
|----------|--------|--------|----------|------|
| Player1  | Player2| SMG    | true     | 1234 |

**Chat Section**  
| Kind     | From   | Text                |
|----------|--------|---------------------|
| TeamChat | Player3| "Orrrb PlAyERz lUl!"   |

### Headers Explanation
- **Deaths Section**
  - `Attacker`: Player responsible for the kill.
  - `AttackerSteamID`: Steam ID of the attacker.
  - `Victim`: Player who was killed.
  - `VictimSteamID`: Steam ID of the victim.
  - `Weapon`: Weapon used.
  - `Headshot`: Whether the kill was a headshot.
  - `Tick`: Game tick when the kill happened.

- **Chat Section**
  - `Kind`: Type of chat (e.g., TeamChat, AllChat).
  - `From`: Name of the player sending the message.
  - `Text`: Content of the message.

## Running the Program
To run the program, open a command prompt or terminal, navigate to the directory containing `HL2DM_Death_Finder.exe`, and use the following command format:

```shell
HL2DM_Death_Finder.exe "path\to\input\dem\files" "path\to\output\csv\files" true
