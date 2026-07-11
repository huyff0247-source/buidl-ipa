#import "GameLogic.h"

#pragma mark - Function Game

uint64_t getMatchGame(uint64_t Moudule_Base) {
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(Moudule_Base + 0xBFD8978);
    if (!isVaildPtr(GameFacade_TypeInfo)) {
        NSLog(@"[ESP] getMatchGame: GameFacade_TypeInfo khong hop le: 0x%llx", GameFacade_TypeInfo);
        return 0;
    }
    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + 0xB8);
    if (!isVaildPtr(GameFacade_Static)) {
        NSLog(@"[ESP] getMatchGame: GameFacade_Static khong hop le: 0x%llx", GameFacade_Static);
        return 0;
    }
    uint64_t matchGame = ReadAddr<uint64_t>(GameFacade_Static + 0x0);
    NSLog(@"[ESP] getMatchGame: TypeInfo=0x%llx Static=0x%llx matchGame=0x%llx", 
          GameFacade_TypeInfo, GameFacade_Static, matchGame);
    return matchGame;
}

uint64_t getMatch(uint64_t matchgame) {
    return ReadAddr<uint64_t>(matchgame + 0x90);
}

uint64_t getLocalPlayer(uint64_t match) {
    return ReadAddr<uint64_t>(match + 0xD8);
}

uint64_t CameraMain(uint64_t matchgame) {
    uint64_t CameraControllerManager = ReadAddr<uint64_t>(matchgame + 0xD8);
    if (!isVaildPtr(CameraControllerManager)) {
        return 0;
    }
    // Camera BAGLCCLIOEK o offset 0x20 (dump moi)
    uint64_t camera = ReadAddr<uint64_t>(CameraControllerManager + 0x20);
    return camera;
}

float* GetViewMatrix(uint64_t cameraMain) {
    if (!isVaildPtr(cameraMain)) return NULL;
    
    // Camera Unity: camera + 0x10 -> internal pointer
    // internal + 0xD8 -> view matrix (16 floats)
    uint64_t v1 = ReadAddr<uint64_t>(cameraMain + 0x10);
    if (!isVaildPtr(v1)) {
        // Thu offset khac: camera + 0x18 hoac camera + 0x20
        v1 = ReadAddr<uint64_t>(cameraMain + 0x18);
        if (!isVaildPtr(v1)) {
            return NULL;
        }
    }
    
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
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x630); // protected ITransformNode GOLAIKOPNJK (HeadNode)
    return getTransNode(BodyPart);
}

uint64_t getHip(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x638); // protected ITransformNode PEMOFNFCLFB (HipNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x668); // protected ITransformNode HNFBCFKKCJP (LeftAnkleNode)
    return getTransNode(BodyPart);
}

uint64_t getRightAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x670); // protected ITransformNode BOHFCEHMJBD (RightAnkleNode)
    return getTransNode(BodyPart);
}

uint64_t getRightToeNode(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x680); // protected ITransformNode JLLMBADGKJP (RightToeNode)
    return getTransNode(BodyPart);
}


uint64_t getLeftShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A0); // protected ITransformNode NBHOEOOCIIG (LeftArmNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C8); // protected ITransformNode KNBJLEHOPIL (LeftForeArmNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B8); // protected ITransformNode PNPBBNDANEM (LeftHandNode)
    return getTransNode(BodyPart);
}

uint64_t getRightShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A8); // protected ITransformNode OEJFBHIIBBG (RightArmNode)
    return getTransNode(BodyPart);
}

uint64_t getRightElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C0); // protected ITransformNode KMIANNCLNOJ (RightForeArmNode)
    return getTransNode(BodyPart);
}

uint64_t getRightHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B0); // protected ITransformNode DIHJDDNIJHP (RightHandNode)
    return getTransNode(BodyPart);
}

bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player) {
    // PlayerID struct o offset 0x3A0 (dump moi)
    COW_GamePlay_PlayerID_o myPlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(localPlayer + 0x3A0);
    COW_GamePlay_PlayerID_o PlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(Player + 0x3A0);

    int myTeamID = myPlayerID.m_TeamID;
    int TeamID = PlayerID.m_TeamID;

    return myTeamID == TeamID;
}

int GetDataUInt16(uint64_t player, int varID) {
    // m_PRIDataPool o offset 0x70 (dump moi)
    uint64_t IPRIDataPool = ReadAddr<uint64_t>(player + 0x70);
    if (isVaildPtr(IPRIDataPool)) {
        // m_Datas o offset 0x10 (ReplicationDataPoolUnsafe) - array of ReplicationDataUnsafe*
        uint64_t v2 = ReadAddr<uint64_t>(IPRIDataPool + 0x10);
        if (isVaildPtr(v2)) {
            // m_Datas[varID]: moi pointer 8 bytes, array bat dau tu offset 0x20
            uint64_t v4 = ReadAddr<uint64_t>(v2 + 0x8 * varID + 0x20);
            if (isVaildPtr(v4)) {
                // ReplicationDataUnsafe.Value o offset 0x18
                int v6 = ReadAddr<int>(v4 + 0x18);
                return v6;
            }
        }
    }
    return 0;
}

int get_CurHP(uint64_t Player) {
    return GetDataUInt16(Player, 0);
}

int get_MaxHP(uint64_t Player) {
    return GetDataUInt16(Player, 1);
}
