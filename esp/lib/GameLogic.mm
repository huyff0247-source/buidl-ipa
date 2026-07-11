#import "GameLogic.h"
#import "Offsets.h"
#include <cstdio>

// ESPLog duoc dinh nghia trong MemoryUtils.mm

// Chan doan buoc con cua getMatchGame (hien tren HUD)
char g_matchDiag[256] = "";

#pragma mark - Function Game

uint64_t getMatchGame(uint64_t Moudule_Base) {
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(Moudule_Base + Off::GameFacade_TypeInfo_RVA);
    ESPLog("getMatchGame: base=0x%llx GameFacade_TypeInfo=0x%llx", Moudule_Base, GameFacade_TypeInfo);
    if (!isVaildPtr(GameFacade_TypeInfo)) {
        snprintf(g_matchDiag, sizeof(g_matchDiag), "TypeInfo=0x%llx (base=0x%llx sai / read fail)", (unsigned long long)GameFacade_TypeInfo, (unsigned long long)Moudule_Base);
        ESPLog("getMatchGame: GameFacade_TypeInfo khong hop le");
        return 0;
    }

    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + Off::GameFacade_Static);
    ESPLog("getMatchGame: GameFacade_Static=0x%llx", GameFacade_Static);
    if (!isVaildPtr(GameFacade_Static)) {
        snprintf(g_matchDiag, sizeof(g_matchDiag), "Static=0x%llx (TypeInfo ok=0x%llx, offset Static sai?)", (unsigned long long)GameFacade_Static, (unsigned long long)GameFacade_TypeInfo);
        ESPLog("getMatchGame: GameFacade_Static khong hop le");
        return 0;
    }

    uint64_t matchGame = ReadAddr<uint64_t>(GameFacade_Static + Off::GameFacade_MatchGame);
    ESPLog("getMatchGame: matchGame=0x%llx", matchGame);
    if (!isVaildPtr(matchGame)) {
        snprintf(g_matchDiag, sizeof(g_matchDiag), "matchGame=0x%llx (Static ok=0x%llx, chua vao tran?)", (unsigned long long)matchGame, (unsigned long long)GameFacade_Static);
    }
    return matchGame;
}

uint64_t getMatch(uint64_t matchgame) {
    uint64_t match = ReadAddr<uint64_t>(matchgame + Off::MatchGame_Match);
    ESPLog("getMatch: match=0x%llx", match);
    return match;
}

uint64_t getLocalPlayer(uint64_t match) {
    uint64_t localPlayer = ReadAddr<uint64_t>(match + Off::Match_LocalPlayer);
    ESPLog("getLocalPlayer: localPlayer=0x%llx", localPlayer);
    return localPlayer;
}

uint64_t CameraMain(uint64_t matchgame) {
    uint64_t CameraControllerManager = ReadAddr<uint64_t>(matchgame + Off::MatchGame_CameraCtrlMgr);
    ESPLog("CameraMain: CameraControllerManager=0x%llx", CameraControllerManager);
    if (!isVaildPtr(CameraControllerManager)) {
        ESPLog("CameraMain: CameraControllerManager khong hop le");
        return 0;
    }

    uint64_t camera = ReadAddr<uint64_t>(CameraControllerManager + Off::CameraCtrlMgr_Camera);
    ESPLog("CameraMain: camera=0x%llx", camera);
    return camera;
}

float* GetViewMatrix(uint64_t cameraMain) {
    // Ma tran View-Projection nam TRUC TIEP tren camera object tai offset 0x444
    // (mode row), da xac dinh bang MTXSCAN (score 20/20, spread 619px).
    // Cach cu (camera+0x10 -> +0xD8) doc ra ma tran rac (row0=[0 0 0 0]) -> bo.
    static float matrix[16];
    for (int i = 0; i < 16; i++) {
        matrix[i] = ReadAddr<float>(cameraMain + Off::Camera_ViewMatrixDirect + i * 0x4);
    }
    ESPLog("GetViewMatrix: cam+0x%llx m0=%.3f m5=%.3f", (unsigned long long)Off::Camera_ViewMatrixDirect, matrix[0], matrix[5]);
    return matrix;
}

uint64_t getTransNode(uint64_t BodyPart) {
    return ReadAddr<uint64_t>(BodyPart + Off::TransformNode_Inner);
}

uint64_t getHead(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::HeadNode);
    return getTransNode(BodyPart);
}

uint64_t getHip(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::HipNode);
    return getTransNode(BodyPart);
}

uint64_t getLeftAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::LeftAnkleNode);
    return getTransNode(BodyPart);
}

uint64_t getRightAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::RightAnkleNode);
    return getTransNode(BodyPart);
}

uint64_t getRightToeNode(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::RightToeNode);
    return getTransNode(BodyPart);
}

uint64_t getLeftShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::LeftArmNode);
    return getTransNode(BodyPart);
}

uint64_t getLeftElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::LeftForeArmNode);
    return getTransNode(BodyPart);
}

uint64_t getLeftHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::LeftHandNode);
    return getTransNode(BodyPart);
}

uint64_t getRightShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::RightArmNode);
    return getTransNode(BodyPart);
}

uint64_t getRightElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::RightForeArmNode);
    return getTransNode(BodyPart);
}

uint64_t getRightHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + Off::RightHandNode);
    return getTransNode(BodyPart);
}

bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player) {
    COW_GamePlay_PlayerID_o myPlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(localPlayer + Off::PlayerID);
    COW_GamePlay_PlayerID_o PlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(Player + Off::PlayerID);

    int myTeamID = myPlayerID.m_TeamID;
    int TeamID = PlayerID.m_TeamID;

    return myTeamID == TeamID;
}

int GetDataUInt16(uint64_t player, int varID) {
    uint64_t IPRIDataPool = ReadAddr<uint64_t>(player + Off::Pawn_PRIDataPool);
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
