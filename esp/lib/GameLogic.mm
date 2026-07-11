#import "GameLogic.h"
#include <stdio.h>
#include <stdarg.h>
#include <time.h>

// Ghi log vao file de debug
void ESPLog(const char *format, ...) {
    FILE *fp = fopen("/var/mobile/Documents/esp_log.txt", "a");
    if (fp) {
        time_t now = time(NULL);
        struct tm *tm_info = localtime(&now);
        char timeStr[26];
        strftime(timeStr, 26, "%Y-%m-%d %H:%M:%S", tm_info);
        fprintf(fp, "[%s] ", timeStr);
        
        va_list args;
        va_start(args, format);
        vfprintf(fp, format, args);
        va_end(args);
        
        fprintf(fp, "\n");
        fclose(fp);
    }
}

#pragma mark - Function Game

uint64_t getMatchGame(uint64_t Moudule_Base) {
    // GameFacade_TypeInfo: 0x9985B70 (cu) -> 0xBFD8978 (moi)
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(Moudule_Base + 0xBFD8978);
    ESPLog("getMatchGame: GameFacade_TypeInfo=0x%llx", GameFacade_TypeInfo);
    if (!isVaildPtr(GameFacade_TypeInfo)) {
        ESPLog("getMatchGame: GameFacade_TypeInfo khong hop le");
        return 0;
    }
    
    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + 0xB8);
    ESPLog("getMatchGame: GameFacade_Static=0x%llx", GameFacade_Static);
    if (!isVaildPtr(GameFacade_Static)) {
        ESPLog("getMatchGame: GameFacade_Static khong hop le");
        return 0;
    }
    
    uint64_t matchGame = ReadAddr<uint64_t>(GameFacade_Static + 0x0);
    ESPLog("getMatchGame: matchGame=0x%llx", matchGame);
    return matchGame;
}

uint64_t getMatch(uint64_t matchgame) {
    uint64_t match = ReadAddr<uint64_t>(matchgame + 0x90);
    ESPLog("getMatch: match=0x%llx", match);
    return match;
}

uint64_t getLocalPlayer(uint64_t match) {
    // 0x58 (cu) -> 0xD8 (moi)
    uint64_t localPlayer = ReadAddr<uint64_t>(match + 0xD8);
    ESPLog("getLocalPlayer: localPlayer=0x%llx", localPlayer);
    return localPlayer;
}

uint64_t CameraMain(uint64_t matchgame) {
    uint64_t CameraControllerManager = ReadAddr<uint64_t>(matchgame + 0xD8);
    ESPLog("CameraMain: CameraControllerManager=0x%llx", CameraControllerManager);
    if (!isVaildPtr(CameraControllerManager)) {
        ESPLog("CameraMain: CameraControllerManager khong hop le");
        return 0;
    }
    
    // Camera BAGLCCLIOEK: 0x18 (cu) -> 0x20 (moi)
    uint64_t camera = ReadAddr<uint64_t>(CameraControllerManager + 0x20);
    ESPLog("CameraMain: camera=0x%llx", camera);
    return camera;
}

float* GetViewMatrix(uint64_t cameraMain) {
    uint64_t v1 = ReadAddr<uint64_t>(cameraMain + 0x10);
    ESPLog("GetViewMatrix: v1=0x%llx", v1);
    
    static float matrix[16];
    for (int i = 0; i < 16; i++) {
        matrix[i] = ReadAddr<float>(v1 + 0xD8 + i * 0x4);
    }
    
    return matrix;
}

uint64_t getTransNode(uint64_t BodyPart) {
    return ReadAddr<uint64_t>(BodyPart + 0x10);
}

uint64_t getHead(uint64_t player) {
    // GOLAIKOPNJK (HeadNode): 0x550 (cu) -> 0x630 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x630);
    return getTransNode(BodyPart);
}

uint64_t getHip(uint64_t player) {
    // PEMOFNFCLFB (HipNode): 0x558 (cu) -> 0x638 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x638);
    return getTransNode(BodyPart);
}

uint64_t getLeftAnkle(uint64_t player) {
    // HNFBCFKKCJP (LeftAnkleNode): 0x588 (cu) -> 0x668 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x668);
    return getTransNode(BodyPart);
}

uint64_t getRightAnkle(uint64_t player) {
    // BOHFCEHMJBD (RightAnkleNode): 0x590 (cu) -> 0x670 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x670);
    return getTransNode(BodyPart);
}

uint64_t getRightToeNode(uint64_t player) {
    // JLLMBADGKJP (RightToeNode): 0x5A0 (cu) -> 0x680 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x680);
    return getTransNode(BodyPart);
}


uint64_t getLeftShoulder(uint64_t player) {
    // NBHOEOOCIIG (LeftArmNode): 0x5B8 (cu) -> 0x6A0 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A0);
    return getTransNode(BodyPart);
}

uint64_t getLeftElbow(uint64_t player) {
    // KNBJLEHOPIL (LeftForeArmNode): 0x5E0 (cu) -> 0x6C8 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C8);
    return getTransNode(BodyPart);
}

uint64_t getLeftHand(uint64_t player) {
    // PNPBBNDANEM (LeftHandNode): 0x5D0 (cu) -> 0x6B8 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B8);
    return getTransNode(BodyPart);
}

uint64_t getRightShoulder(uint64_t player) {
    // OEJFBHIIBBG (RightArmNode): 0x5C0 (cu) -> 0x6A8 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A8);
    return getTransNode(BodyPart);
}

uint64_t getRightElbow(uint64_t player) {
    // KMIANNCLNOJ (RightForeArmNode): 0x5D8 (cu) -> 0x6C0 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C0);
    return getTransNode(BodyPart);
}

uint64_t getRightHand(uint64_t player) {
    // DIHJDDNIJHP (RightHandNode): 0x5C8 (cu) -> 0x6B0 (moi)
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B0);
    return getTransNode(BodyPart);
}

bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player) {
    // BMIGBNMBAJH (PlayerID): 0x2D0 (cu) -> 0x3A0 (moi)
    COW_GamePlay_PlayerID_o myPlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(localPlayer + 0x3A0);
    COW_GamePlay_PlayerID_o PlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(Player + 0x3A0);
    
    int myTeamID = myPlayerID.m_TeamID;
    int TeamID = PlayerID.m_TeamID;
    
    return myTeamID == TeamID;
}

int GetDataUInt16(uint64_t player, int varID) {
    // m_PRIDataPool: 0x68 (cu) -> 0x70 (moi)
    uint64_t IPRIDataPool = ReadAddr<uint64_t>(player + 0x70);
    if (isVaildPtr(IPRIDataPool)) {
        uint64_t v2 = ReadAddr<uint64_t>(IPRIDataPool + 0x10);
        uint64_t v4 = ReadAddr<uint64_t>(v2 + 0x8 * varID + 0x20);
        int v6 = ReadAddr<int>(v4 + 0x18);
        return v6;
    }
    return 0;
}

int get_CurHP(uint64_t Player) {
    return GetDataUInt16(Player, 0);
}

int get_MaxHP(uint64_t Player) {
    return GetDataUInt16(Player, 1);
}
