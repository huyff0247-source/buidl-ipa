// ==========================================================================
// Offsets.h - TU DONG SINH boi gen_offsets.py. KHONG SUA TAY file nay.
// Sua offsets_map.json roi chay: python3 gen_offsets.py
// Nguon dump index: /rootfs/private/var/mobile/Containers/Shared/AppGroup/.jbroot-F6780BDA18D2BC29/var/mobile/grid_agent_sandbox/offindex.json
// ==========================================================================
#ifndef Offsets_h
#define Offsets_h
#include <cstdint>

namespace Off {
    constexpr uint64_t AimRotation                = 0x4E8;  // Player.MJALKGNKGOA  (private Quaternion)
    constexpr uint64_t Array_DataStart            = 0x20;  // manual
    constexpr uint64_t CameraCtrlMgr_Camera       = 0x20;  // manual
    constexpr uint64_t Camera_ViewMatrixPtr       = 0x10;  // manual
    constexpr uint64_t DictKeyByte_Stride         = 0x18;  // manual
    constexpr uint64_t DictKeyByte_ValOff         = 0x10;  // manual
    constexpr uint64_t DictKeyObj_Stride          = 0x28;  // manual
    constexpr uint64_t DictKeyObj_ValOff          = 0x20;  // manual
    constexpr uint64_t Dict_Count                 = 0x20;  // manual
    constexpr uint64_t Dict_Entries               = 0x18;  // manual
    constexpr uint64_t GameFacade_MatchGame       = 0x0;  // manual
    constexpr uint64_t GameFacade_Static          = 0xB8;  // manual
    constexpr uint64_t GameFacade_TypeInfo_RVA    = 0xBFD8978;  // manual
    constexpr uint64_t HeadNode                   = 0x630;  // Player.GOLAIKOPNJK  (protected ITransformNode)
    constexpr uint64_t HipNode                    = 0x638;  // Player.PEMOFNFCLFB  (protected ITransformNode)
    constexpr uint64_t IsFiring                   = 0x6F0;  // Player.MPJBMKODJMF  (private bool)
    constexpr uint64_t IsVisible                  = 0x930;  // Player.LMACIGOFJNL  (protected int)
    constexpr uint64_t LeftAnkleNode              = 0x668;  // Player.HNFBCFKKCJP  (protected ITransformNode)
    constexpr uint64_t LeftArmNode                = 0x6A0;  // Player.NBHOEOOCIIG  (protected ITransformNode)
    constexpr uint64_t LeftForeArmNode            = 0x6C8;  // Player.KNBJLEHOPIL  (protected ITransformNode)
    constexpr uint64_t LeftHandNode               = 0x6B8;  // Player.PNPBBNDANEM  (protected ITransformNode)
    constexpr uint64_t List_Items                 = 0x10;  // manual
    constexpr uint64_t List_Size                  = 0x18;  // manual
    constexpr uint64_t MatchGame_CameraCtrlMgr    = 0xD8;  // manual
    constexpr uint64_t MatchGame_Match            = 0x90;  // manual
    constexpr uint64_t Match_LocalPlayer          = 0xD8;  // manual
    constexpr uint64_t Pawn_MainCameraTransform   = 0x380;  // manual
    constexpr uint64_t Pawn_PRIDataPool           = 0x70;  // manual
    constexpr uint64_t PlayerID                   = 0x3A0;  // Player.BMIGBNMBAJH  (protected BHGGAEEHJCO)
    constexpr uint64_t PlayerID_TeamID            = 0x0;  // manual
    constexpr uint64_t RightAnkleNode             = 0x670;  // Player.BOHFCEHMJBD  (protected ITransformNode)
    constexpr uint64_t RightArmNode               = 0x6A8;  // Player.OEJFBHIIBBG  (protected ITransformNode)
    constexpr uint64_t RightForeArmNode           = 0x6C0;  // Player.KMIANNCLNOJ  (protected ITransformNode)
    constexpr uint64_t RightHandNode              = 0x6B0;  // Player.DIHJDDNIJHP  (protected ITransformNode)
    constexpr uint64_t RightToeNode               = 0x680;  // Player.JLLMBADGKJP  (protected ITransformNode)
    constexpr uint64_t TransformNode_Inner        = 0x10;  // manual
    constexpr uint64_t ViewMatrix_Offset          = 0xD8;  // manual

    // --- Container Player trong class match (danh sach ung vien) ---
    constexpr uint64_t MatchListCands[] = { 0x158, 0x160, 0x578 };
    constexpr int MatchListCands_N = 3;
    constexpr uint64_t MatchDictObjCands[] = { 0x128, 0x130, 0x140, 0x150, 0x5E0, 0x5E8 };
    constexpr int MatchDictObjCands_N = 6;
    constexpr uint64_t MatchDictByteCands[] = { 0x148 };
    constexpr int MatchDictByteCands_N = 1;
}

#endif // Offsets_h
