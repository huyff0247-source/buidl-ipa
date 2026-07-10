#ifndef GameLogic_h
#define GameLogic_h

#import "MemoryUtils.h"
#import "UnityMath.h"

#pragma mark - Function Game

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

// --- Bone offsets (Player class) ---
uint64_t getHead(uint64_t player);          // 0x630 (GOLAIKOPNJK - HeadNode)
uint64_t getHip(uint64_t player);           // 0x638 (PEMOFNFCLFB - HipNode)
uint64_t getLeftAnkle(uint64_t player);     // 0x668 (HNFBCFKKCJP - LeftAnkleNode)
uint64_t getRightAnkle(uint64_t player);    // 0x670 (BOHFCEHMJBD - RightAnkleNode)
uint64_t getRightToeNode(uint64_t player);  // 0x680 (JLLMBADGKJP - RightToeNode)
uint64_t getLeftShoulder(uint64_t player);  // 0x6A0 (NBHOEOOCIIG - LeftArmNode)
uint64_t getRightShoulder(uint64_t player); // 0x6A8 (OEJFBHIIBBG - RightArmNode)
uint64_t getLeftHand(uint64_t player);      // 0x6B8 (PNPBBNDANEM - LeftHandNode)
uint64_t getRightHand(uint64_t player);     // 0x6B0 (DIHJDDNIJHP - RightHandNode)
uint64_t getRightElbow(uint64_t player);    // 0x6C0 (KMIANNCLNOJ - RightForeArmNode)
uint64_t getLeftElbow(uint64_t player);     // 0x6C8 (KNBJLEHOPIL - LeftForeArmNode)

// --- Anti-Detection Functions ---
// Smooth aim với Slerp + random delay + miss chance
void set_aim_smooth(uint64_t player, Quaternion targetRotation, float smoothFactor);
// Random offset để aim không chính xác 100%
Vector3 getRandomAimOffset();
// Check xem có nên aim không (random miss)
bool shouldAim();
// Random delay giữa các lần aim
float getRandomAimDelay();

#endif
