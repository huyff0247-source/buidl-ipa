#ifndef MemoryUtils_h
#define MemoryUtils_h

#include <mach/mach.h>
#include <sys/sysctl.h>
#include <string>

#pragma mark - Get PID

static mach_port_t get_task;
static pid_t Processpid;

extern "C" kern_return_t mach_vm_region_recurse(vm_map_t                 map,
                                                mach_vm_address_t        *address,
                                                mach_vm_size_t           *size,
                                                uint32_t                 *depth,
                                                vm_region_recurse_info_t info,
                                                mach_msg_type_number_t   *infoCnt);

inline bool isVaildPtr(long addr){
    return addr > 0x100000000 && addr < 0x1600000000;
}

pid_t GetGameProcesspid(char* GameProcessName);
pid_t GetGamePidByBundle(const char *bundleId);
void  LogAllProcesses(void);
uint64_t GetRemoteModuleBase(mach_port_t task, const char *moduleName, bool logAll);
vm_map_offset_t GetGameModule_Base(char* GameProcessName);

// Ghi ly do that bai gan nhat cua GetGameModule_Base (de hien tren HUD)
extern char g_baseErr[256];

bool _read(long addr, void *buffer, int len);
bool _write(long addr, const void *buffer, int len);

// Debug logging - ghi vao /var/mobile/Documents/esp_log.txt
void ESPLog(const char *format, ...);

template<typename T>
T ReadAddr(long address) {
    T data{};
    _read(address, reinterpret_cast<void *>(&data), sizeof(T));
    return data;
}

template<typename T>
bool WriteAddr(long address, const T &data) {
    return _write(address, reinterpret_cast<const void *>(&data), sizeof(T));
}

#endif
