#import "GameLogic.h"

#pragma mark - Function Game

uint64_t getMatchGame(uint64_t Moudule_Base) {
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(Moudule_Base + 0xBFD0EB8);
    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + 0xB8);
    return ReadAddr<uint64_t>(GameFacade_Static + 0x0);
}

uint64_t getMatch(uint64_t matchgame) {
    return ReadAddr<uint64_t>(matchgame + 0x90); // protected EMKJHAJNPDH m_Match; // 0x90
}

uint64_t getLocalPlayer(uint64_t match) {
    return ReadAddr<uint64_t>(match + 0xD8); // protected Player PDBGEOANOEP; // 0xD8
}

uint64_t CameraMain(uint64_t matchgame) {
    uint64_t CameraControllerManager = ReadAddr<uint64_t>(matchgame + 0xD8);
    // CameraControllerManager.BAGLCCLIOEK (Camera) // 0x20
    return ReadAddr<uint64_t>(CameraControllerManager + 0x20);
}

float* GetViewMatrix(uint64_t cameraMain) {
    uint64_t v1 = ReadAddr<uint64_t>(cameraMain + 0x10);
    
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
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x630); // protected ITransformNode GOLAIKOPNJK; // 0x630 (HeadNode)
    return getTransNode(BodyPart);
}

uint64_t getHip(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x638); // protected ITransformNode PEMOFNFCLFB; // 0x638 (HipNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x668); // protected ITransformNode HNFBCFKKCJP; // 0x668 (m_LeftAnkleNode)
    return getTransNode(BodyPart);
}

uint64_t getRightAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x670); // protected ITransformNode BOHFCEHMJBD; // 0x670 (m_RightAnkleNode)
    return getTransNode(BodyPart);
}

uint64_t getRightToeNode(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x680); // protected ITransformNode JLLMBADGKJP; // 0x680 (m_RightToeNode)
    return getTransNode(BodyPart);
}


uint64_t getLeftShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A0); // protected ITransformNode NBHOEOOCIIG; // 0x6A0 (m_LeftArmNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C8); // protected ITransformNode KNBJLEHOPIL; // 0x6C8 (m_LeftForeArmNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B8); // protected ITransformNode PNPBBNDANEM; // 0x6B8 (m_LeftHandNode)
    return getTransNode(BodyPart);
}

uint64_t getRightShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A8); // protected ITransformNode OEJFBHIIBBG; // 0x6A8 (m_RightArmNode)
    return getTransNode(BodyPart);
}

uint64_t getRightElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C0); // protected ITransformNode KMIANNCLNOJ; // 0x6C0 (m_RightForeArmNode)
    return getTransNode(BodyPart);
}

uint64_t getRightHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B0); // protected ITransformNode DIHJDDNIJHP; // 0x6B0 (m_RightHandNode)
    return getTransNode(BodyPart);
}

bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player) {
    // BHGGAEEHJCO struct: m_Value=0x0, m_ID=0x4, m_TeamID=0x8, m_ShortID=0x9, m_IDMask=0x10
    // protected BHGGAEEHJCO BMIGBNMBAJH; // 0x3A0
    COW_GamePlay_PlayerID_o myPlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(localPlayer + 0x3A0);
    COW_GamePlay_PlayerID_o PlayerID = ReadAddr<COW_GamePlay_PlayerID_o>(Player + 0x3A0);
    
    int myTeamID = myPlayerID.m_TeamID;
    int TeamID = PlayerID.m_TeamID;
    
    return myTeamID == TeamID;
}

int GetDataUInt16(uint64_t player, int varID) {
    // protected IPRIDataPool m_PRIDataPool; // 0x70 (ReplicationEntity)
    uint64_t IPRIDataPool = ReadAddr<uint64_t>(player + 0x70);
    if (isVaildPtr(IPRIDataPool)) {
        // ReplicationDataPool.m_Datas (ReplicationData[]) // 0x10
        uint64_t v2 = ReadAddr<uint64_t>(IPRIDataPool + 0x10);
        // ReplicationData size = 0x20 (GroupID=0x10, Value=0x18)
        uint64_t v4 = ReadAddr<uint64_t>(v2 + 0x20 * varID + 0x20);
        // ReplicationData.Value (ReplicationDataValueUnion) // 0x18
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

#pragma mark - Anti-Detection Functions

// Random offset để aim không chính xác 100% vào đầu
Vector3 getRandomAimOffset() {
    // Random offset ±0.15m (giống người thật)
    float offsetX = ((rand() % 100) / 100.0f - 0.5f) * 0.3f;
    float offsetY = ((rand() % 100) / 100.0f - 0.5f) * 0.3f;
    float offsetZ = ((rand() % 100) / 100.0f - 0.5f) * 0.2f;
    return Vector3(offsetX, offsetY, offsetZ);
}

// Check xem có nên aim không (5% miss chance)
bool shouldAim() {
    // 95% aim, 5% miss để giống người thật
    return (rand() % 100) >= 5;
}

// Random delay giữa các lần aim (50-150ms)
float getRandomAimDelay() {
    return 0.05f + (rand() % 100) / 1000.0f;
}

// Smooth aim với Slerp + humanization - tối ưu cho 60fps
void set_aim_smooth(uint64_t player, Quaternion targetRotation, float smoothFactor) {
    if (!isVaildPtr(player)) return;

    // Đọc rotation hiện tại
    Quaternion currentRot = ReadAddr<Quaternion>(player + 0x4E8);

    // Slerp với factor cao (0.3-0.8) để aim mượt nhưng nhanh, dính chặt player
    // Factor càng cao càng nhanh nhưng vẫn mượt (không giật)
    Quaternion newRot = Quaternion::Slerp(currentRot, targetRotation, smoothFactor);

    // Ghi rotation mới
    WriteAddr<Quaternion>(player + 0x4E8, newRot);
}
