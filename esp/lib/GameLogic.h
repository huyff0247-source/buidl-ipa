#ifndef GameLogic_h
#define GameLogic_h

#import "MemoryUtils.h"
#import "UnityMath.h"

#pragma mark - Function Game

// === Core Game Functions ===
uint64_t getMatchGame(uint64_t Moudule_Base);
uint64_t getMatch(uint64_t matchgame);
uint64_t CameraMain(uint64_t matchgame);
float* GetViewMatrix(uint64_t cameraMain);
uint64_t getTransNode(uint64_t BodyPart);
uint64_t getLocalPlayer(uint64_t match);
int get_CurHP(uint64_t Player);
int get_MaxHP(uint64_t Player);
bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player);
int GetDataUInt16(uint64_t player, int varID);

// === Bone Nodes (Player class ITransformNode) ===
// Dựa trên dump.cs, Player class có 26 ITransformNode ở các offset 0x630-0x6C8 và 0x970-0x9A0
uint64_t getHead(uint64_t player);           // 0x630 - GOLAIKOPNJK
uint64_t getHip(uint64_t player);            // 0x638 - PEMOFNFCLFB
uint64_t getNeck(uint64_t player);           // 0x640 - DIDHPFKMJJE
uint64_t getSpine(uint64_t player);          // 0x648 - KAKOKIHEPCF
uint64_t getChest(uint64_t player);          // 0x650 - GCEICMOOFIA
uint64_t getPelvis(uint64_t player);         // 0x658 - CLOEKEADCHD
uint64_t getLeftUpLeg(uint64_t player);      // 0x660 - KNFKIDHJCCO
uint64_t getRightUpLeg(uint64_t player);     // 0x668 - HNFBCFKKCJP
uint64_t getLeftLeg(uint64_t player);        // 0x670 - BOHFCEHMJBD
uint64_t getRightLeg(uint64_t player);       // 0x678 - BIPBNNIFCNO
uint64_t getLeftFoot(uint64_t player);       // 0x680 - JLLMBADGKJP
uint64_t getRightFoot(uint64_t player);      // 0x688 - INHGPBHOKPF
uint64_t getLeftToe(uint64_t player);        // 0x690 - OEHAGFIGILO
uint64_t getRightToe(uint64_t player);       // 0x6A0 - NBHOEOOCIIG
uint64_t getLeftClav(uint64_t player);       // 0x6A8 - OEJFBHIIBBG
uint64_t getRightClav(uint64_t player);      // 0x6B0 - DIHJDDNIJHP
uint64_t getLeftShoulder(uint64_t player);   // 0x6B8 - PNPBBNDANEM (LeftArmNode)
uint64_t getRightShoulder(uint64_t player);  // 0x6C0 - KMIANNCLNOJ (RightArmNode)
uint64_t getLeftElbow(uint64_t player);      // 0x6C8 - KNBJLEHOPIL (LeftForeArmNode)
uint64_t getRightElbow(uint64_t player);     // 0x970 - POIIJNJLGCO (RightForeArmNode)
uint64_t getLeftHand(uint64_t player);       // 0x978 - GKAGFCKBHJB
uint64_t getRightHand(uint64_t player);      // 0x980 - LAIEJLCIJNC
uint64_t getLeftAnkle(uint64_t player);      // 0x988 - BNDLKFFHENC
uint64_t getRightAnkle(uint64_t player);     // 0x990 - NALHCKGKDOF
uint64_t getLeftKnee(uint64_t player);       // 0x998 - LKCDAFFDJNK
uint64_t getRightKnee(uint64_t player);      // 0x9A0 - FLGNFGPLGNH

// === Anti-Cheat Bypass ===
// Hook các hàm anti-cheat để bypass memory scanning detection
void InstallAntiCheatBypass();
void UninstallAntiCheatBypass();
bool IsAntiCheatBypassed();

#endif
