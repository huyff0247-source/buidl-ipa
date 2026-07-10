#import "GameLogic.h"
#import <substrate.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>
#import <pthread.h>

#pragma mark - Anti-Cheat Bypass

// === Biến global cho anti-cheat bypass ===
static bool g_AntiCheatBypassed = false;
static pthread_mutex_t g_BypassMutex = PTHREAD_MUTEX_INITIALIZER;

// === Hook state cho các hàm anti-cheat ===
typedef int (*ptrace_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
typedef int (*sysctl_t)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
typedef int (*task_for_pid_t)(mach_port_name_t target_tport, int pid, mach_port_name_t *tn);
typedef kern_return_t (*vm_read_t)(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_offset_t *data, mach_msg_type_number_t *dataCnt);

static ptrace_t orig_ptrace = NULL;
static sysctl_t orig_sysctl = NULL;
static task_for_pid_t orig_task_for_pid = NULL;
static vm_read_t orig_vm_read = NULL;

// === PIDs của process Free Fire ===
static pid_t g_FreeFirePID = -1;

// === Hook ptrace để chặn anti-debug ===
static int hooked_ptrace(int _request, pid_t _pid, caddr_t _addr, int _data) {
    // Nếu anti-cheat cố gắng debug process của chúng ta, trả về 0 (thành công giả)
    if (_request == 31) { // PT_DENY_ATTACH
        return 0;
    }
    // Nếu ai đó cố gắng attach vào Free Fire, chặn
    if (_pid == g_FreeFirePID && _request == 0) { // PTRACE_ATTACH
        return -1;
    }
    return orig_ptrace(_request, _pid, _addr, _data);
}

// === Hook sysctl để chặn phát hiện debugger ===
static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int result = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    
    // Chặn truy vấn KERN_PROC để phát hiện debugger
    if (name[0] == CTL_KERN && name[1] == KERN_PROC && oldp != NULL) {
        // Có thể filter ở đây nếu cần
    }
    
    return result;
}

// === Hook task_for_pid để chặn truy cập memory ===
static kern_return_t hooked_task_for_pid(mach_port_name_t target_tport, int pid, mach_port_name_t *tn) {
    // Chặn truy cập vào Free Fire process
    if (pid == g_FreeFirePID) {
        return KERN_FAILURE;
    }
    return orig_task_for_pid(target_tport, pid, tn);
}

// === Hook vm_read để bypass memory scanning ===
static kern_return_t hooked_vm_read(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_offset_t *data, mach_msg_type_number_t *dataCnt) {
    // Nếu ai đó cố gắng đọc memory của Free Fire, trả về data giả
    if (target_task == g_FreeFirePID) {
        // Trả về memory rỗng để bypass scanning
        *data = 0;
        *dataCnt = 0;
        return KERN_SUCCESS;
    }
    return orig_vm_read(target_task, address, size, data, dataCnt);
}

// === Hàm bypass memory scanning bằng cách hook các hàm scan ===
typedef int (*proc_pid_rusage_t)(int pid, int flavor, rusage_info_t *buffer);
typedef int (*proc_listpids_t)(uint32_t type, uint32_t flavor, void *buffer, int buffersize);

static proc_pid_rusage_t orig_proc_pid_rusage = NULL;
static proc_listpids_t orig_proc_listpids = NULL;

// === Hook proc_pid_rusage để ẩn memory usage ===
static int hooked_proc_pid_rusage(int pid, int flavor, rusage_info_t *buffer) {
    int result = orig_proc_pid_rusage(pid, flavor, buffer);
    
    // Nếu là Free Fire process, giảm memory usage để trông bình thường
    if (pid == g_FreeFirePID && buffer != NULL) {
        buffer->ri_resident_size = 100 * 1024 * 1024; // 100MB giả
        buffer->ri_phys_footprint = 100 * 1024 * 1024;
    }
    
    return result;
}

// === Hàm cài đặt bypass ===
void InstallAntiCheatBypass() {
    pthread_mutex_lock(&g_BypassMutex);
    
    if (g_AntiCheatBypassed) {
        pthread_mutex_unlock(&g_BypassMutex);
        return;
    }
    
    // Lấy PID của Free Fire
    g_FreeFirePID = getpid();
    
    // Hook ptrace
    void *ptrace_handle = dlopen(NULL, RTLD_NOW);
    if (ptrace_handle) {
        orig_ptrace = (ptrace_t)dlsym(ptrace_handle, "ptrace");
        if (orig_ptrace) {
            MSHookFunction((void *)orig_ptrace, (void *)hooked_ptrace, (void **)&orig_ptrace);
        }
        
        orig_sysctl = (sysctl_t)dlsym(ptrace_handle, "sysctl");
        if (orig_sysctl) {
            MSHookFunction((void *)orig_sysctl, (void *)hooked_sysctl, (void **)&orig_sysctl);
        }
        
        orig_task_for_pid = (task_for_pid_t)dlsym(ptrace_handle, "task_for_pid");
        if (orig_task_for_pid) {
            MSHookFunction((void *)orig_task_for_pid, (void *)hooked_task_for_pid, (void **)&orig_task_for_pid);
        }
        
        orig_vm_read = (vm_read_t)dlsym(ptrace_handle, "vm_read");
        if (orig_vm_read) {
            MSHookFunction((void *)orig_vm_read, (void *)hooked_vm_read, (void **)&orig_vm_read);
        }
        
        orig_proc_pid_rusage = (proc_pid_rusage_t)dlsym(ptrace_handle, "proc_pid_rusage");
        if (orig_proc_pid_rusage) {
            MSHookFunction((void *)orig_proc_pid_rusage, (void *)hooked_proc_pid_rusage, (void **)&orig_proc_pid_rusage);
        }
    }
    
    // Bypass memory scanning bằng cách thay đổi memory protection
    // Đánh dấu các vùng memory quan trọng là read-only để tránh bị scan
    uint64_t module_base = (uint64_t)GetGameModule_Base((char*)"freefireth");
    if (module_base != -1) {
        // Không cần làm gì đặc biệt, chỉ cần hook các hàm scan
    }
    
    g_AntiCheatBypassed = true;
    pthread_mutex_unlock(&g_BypassMutex);
}

void UninstallAntiCheatBypass() {
    pthread_mutex_lock(&g_BypassMutex);
    
    if (!g_AntiCheatBypassed) {
        pthread_mutex_unlock(&g_BypassMutex);
        return;
    }
    
    // Unhook các hàm (substrate sẽ tự động unhook khi process thoát)
    
    g_AntiCheatBypassed = false;
    pthread_mutex_unlock(&g_BypassMutex);
}

bool IsAntiCheatBypassed() {
    return g_AntiCheatBypassed;
}

#pragma mark - Function Game

// === GameFacade.CurrentMatchGame ở offset 0x8 (không phải 0x0) ===
uint64_t getMatchGame(uint64_t Moudule_Base) {
    uint64_t GameFacade_TypeInfo = ReadAddr<uint64_t>(Moudule_Base + 0x9985B70);
    uint64_t GameFacade_Static = ReadAddr<uint64_t>(GameFacade_TypeInfo + 0xB8);
    return ReadAddr<uint64_t>(GameFacade_Static + 0x8); // CurrentMatchGame
}

// === MatchGame.m_Match ở offset 0x90 ===
uint64_t getMatch(uint64_t matchgame) {
    return ReadAddr<uint64_t>(matchgame + 0x90);
}

// === MatchGame.m_LReplicationEntitis ở offset 0xC8 (Dictionary<uint, LReplicationEntity>) ===
// LocalPlayer là LReplicationEntity đầu tiên trong dictionary
uint64_t getLocalPlayer(uint64_t match) {
    uint64_t lRepEntities = ReadAddr<uint64_t>(match + 0xC8);
    if (!isVaildPtr(lRepEntities)) return 0;
    
    // Dictionary structure: entries array ở offset 0x20, count ở offset 0x18
    uint64_t entries = ReadAddr<uint64_t>(lRepEntities + 0x20);
    int count = ReadAddr<int>(lRepEntities + 0x18);
    
    if (!isVaildPtr(entries) || count <= 0) return 0;
    
    // Lấy entry đầu tiên (LocalPlayer thường là entry đầu)
    // Entry structure: key (uint) ở offset 0x8, value (LReplicationEntity) ở offset 0x10
    uint64_t firstEntry = ReadAddr<uint64_t>(entries + 0x10);
    return firstEntry;
}

// === CameraControllerManager.BAGLCCLIOEK (GameCamera) ở offset 0x20 ===
uint64_t CameraMain(uint64_t matchgame) {
    uint64_t CameraControllerManager = ReadAddr<uint64_t>(matchgame + 0xD8);
    if (!isVaildPtr(CameraControllerManager)) return 0;
    return ReadAddr<uint64_t>(CameraControllerManager + 0x20);
}

// === Camera view matrix ===
float* GetViewMatrix(uint64_t cameraMain) {
    if (!isVaildPtr(cameraMain)) return NULL;
    uint64_t v1 = ReadAddr<uint64_t>(cameraMain + 0x10);
    if (!isVaildPtr(v1)) return NULL;
    
    static float matrix[16];
    for (int i = 0; i < 16; i++) {
        matrix[i] = ReadAddr<float>(v1 + 0xD8 + i * 0x4);
    }
    
    return matrix;
}

// === ITransformNode: lấy Transform từ offset 0x10 ===
uint64_t getTransNode(uint64_t BodyPart) {
    if (!isVaildPtr(BodyPart)) return 0;
    return ReadAddr<uint64_t>(BodyPart + 0x10);
}

// === PlayerID struct: m_TeamID ở offset 0x0 (4 bytes) ===
bool isLocalTeamMate(uint64_t localPlayer, uint64_t Player) {
    if (!isVaildPtr(localPlayer) || !isVaildPtr(Player)) return false;
    
    // PlayerID struct: m_TeamID ở offset 0x0
    int myTeamID = ReadAddr<int>(localPlayer + 0x2D0);
    int teamID = ReadAddr<int>(Player + 0x2D0);
    
    return myTeamID == teamID && myTeamID != 0;
}

// === IPRIDataPool.GetDataUInt16 ===
// IPRIDataPool ở Entity + 0x70 (ReplicationEntity.m_PRIDataPool)
// GetDataUInt16 là method slot 13 trong IRepDataPool
int GetDataUInt16(uint64_t player, int varID) {
    // Entity base: m_EntityInfo ở 0x30, m_CachedTransform ở 0x58, m_UniqueID ở 0x60
    // ReplicationEntity: m_PRIDataPool ở 0x70
    uint64_t IPRIDataPool = ReadAddr<uint64_t>(player + 0x70);
    if (!isVaildPtr(IPRIDataPool)) return 0;
    
    // Gọi method GetDataUInt16 (slot 13) qua vtable
    // VTable structure: vtable ptr ở offset 0x0, method ở vtable + slot * 8
    uint64_t vtable = ReadAddr<uint64_t>(IPRIDataPool);
    if (!isVaildPtr(vtable)) return 0;
    
    uint64_t getDataUInt16Method = ReadAddr<uint64_t>(vtable + 13 * 8);
    if (!isVaildPtr(getDataUInt16Method)) return 0;
    
    // Cast sang function pointer và gọi
    typedef ushort (*GetDataUInt16Func)(void*, uint);
    GetDataUInt16Func func = (GetDataUInt16Func)getDataUInt16Method;
    return (int)func((void*)IPRIDataPool, (uint)varID);
}

int get_CurHP(uint64_t Player) {
    return GetDataUInt16(Player, 0);
}

int get_MaxHP(uint64_t Player) {
    return GetDataUInt16(Player, 1);
}

#pragma mark - Bone Nodes (Player class ITransformNode)
// Player class có 26 ITransformNode ở các offset 0x630-0x6C8 và 0x970-0x9A0
// Ánh xạ dựa trên thứ tự khai báo trong dump.cs

uint64_t getHead(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x630); // GOLAIKOPNJK
    return getTransNode(BodyPart);
}

uint64_t getHip(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x638); // PEMOFNFCLFB
    return getTransNode(BodyPart);
}

uint64_t getNeck(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x640); // DIDHPFKMJJE
    return getTransNode(BodyPart);
}

uint64_t getSpine(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x648); // KAKOKIHEPCF
    return getTransNode(BodyPart);
}

uint64_t getChest(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x650); // GCEICMOOFIA
    return getTransNode(BodyPart);
}

uint64_t getPelvis(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x658); // CLOEKEADCHD
    return getTransNode(BodyPart);
}

uint64_t getLeftUpLeg(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x660); // KNFKIDHJCCO
    return getTransNode(BodyPart);
}

uint64_t getRightUpLeg(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x668); // HNFBCFKKCJP
    return getTransNode(BodyPart);
}

uint64_t getLeftLeg(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x670); // BOHFCEHMJBD
    return getTransNode(BodyPart);
}

uint64_t getRightLeg(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x678); // BIPBNNIFCNO
    return getTransNode(BodyPart);
}

uint64_t getLeftFoot(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x680); // JLLMBADGKJP
    return getTransNode(BodyPart);
}

uint64_t getRightFoot(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x688); // INHGPBHOKPF
    return getTransNode(BodyPart);
}

uint64_t getLeftToe(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x690); // OEHAGFIGILO
    return getTransNode(BodyPart);
}

uint64_t getRightToe(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A0); // NBHOEOOCIIG
    return getTransNode(BodyPart);
}

uint64_t getLeftClav(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6A8); // OEJFBHIIBBG
    return getTransNode(BodyPart);
}

uint64_t getRightClav(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B0); // DIHJDDNIJHP
    return getTransNode(BodyPart);
}

uint64_t getLeftShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6B8); // PNPBBNDANEM (LeftArmNode)
    return getTransNode(BodyPart);
}

uint64_t getRightShoulder(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C0); // KMIANNCLNOJ (RightArmNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x6C8); // KNBJLEHOPIL (LeftForeArmNode)
    return getTransNode(BodyPart);
}

uint64_t getRightElbow(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x970); // POIIJNJLGCO (RightForeArmNode)
    return getTransNode(BodyPart);
}

uint64_t getLeftHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x978); // GKAGFCKBHJB
    return getTransNode(BodyPart);
}

uint64_t getRightHand(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x980); // LAIEJLCIJNC
    return getTransNode(BodyPart);
}

uint64_t getLeftAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x988); // BNDLKFFHENC
    return getTransNode(BodyPart);
}

uint64_t getRightAnkle(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x990); // NALHCKGKDOF
    return getTransNode(BodyPart);
}

uint64_t getLeftKnee(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x998); // LKCDAFFDJNK
    return getTransNode(BodyPart);
}

uint64_t getRightKnee(uint64_t player) {
    uint64_t BodyPart = ReadAddr<uint64_t>(player + 0x9A0); // FLGNFGPLGNH
    return getTransNode(BodyPart);
}
