#import "MemoryUtils.h"
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

pid_t GetGameProcesspid(char* GameProcessName) {
    size_t length = 0;
    static const int name[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    int err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
    
    if (err == -1) {
        err = errno;
    }
    
    if (err == 0) {
        struct kinfo_proc *procBuffer = (struct kinfo_proc *)malloc(length);
        if (procBuffer == NULL) {
            return -1;
        }
        
        err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, procBuffer, &length, NULL, 0);
        if (err == -1) {
            err = errno;
            free(procBuffer);
            return -1;
        }
        
        int count = (int)length / sizeof(struct kinfo_proc);
        for (int i = 0; i < count; ++i) {
            const char *procname = procBuffer[i].kp_proc.p_comm;
            pid_t Processpid = procBuffer[i].kp_proc.p_pid;
            
            if (strstr(procname, GameProcessName)) {
                free(procBuffer);
                return Processpid;
            }
        }
        
        free(procBuffer);
    }
    
    return -1;
}

vm_map_offset_t GetGameModule_Base(char* GameProcessName) {
    vm_map_offset_t vmoffset = 0;
    vm_map_size_t vmsize = 0;
    uint32_t nesting_depth = 0;
    struct vm_region_submap_info_64 vbr;
    mach_msg_type_number_t vbrcount = 16;
    
    pid_t pid = GetGameProcesspid(GameProcessName);
    if (pid == -1) {
        ESPLog("GetGameModule_Base: Khong tim thay process %s", GameProcessName);
        return 0;
    }
    
    ESPLog("GetGameModule_Base: Tim thay pid=%d cho %s", pid, GameProcessName);
    
    kern_return_t kret = task_for_pid(mach_task_self(), pid, &get_task);
    
    if (get_task != MACH_PORT_NULL) {
        kern_return_t kr = mach_vm_region_recurse(get_task, &vmoffset, &vmsize, &nesting_depth, (vm_region_recurse_info_t)&vbr, &vbrcount);
        if (kr == KERN_SUCCESS) {
            ESPLog("GetGameModule_Base: Module base = 0x%llx (size=0x%llx)", vmoffset, vmsize);
            return vmoffset;
        } else {
            ESPLog("GetGameModule_Base: mach_vm_region_recurse that bai: %d", kr);
        }
    } else {
        ESPLog("GetGameModule_Base: task_for_pid that bai");
    }
    
    return 0;
}

bool _read(long addr, void *buffer, int len)
{
    if (!isVaildPtr(addr)) return false;
    vm_size_t size = 0;
    kern_return_t error = vm_read_overwrite(get_task, (vm_address_t)addr, len, (vm_address_t)buffer, &size);
    if(error != KERN_SUCCESS || size != len)
    {
        return false;
    }
    return true;
}

bool _write(long addr, const void *buffer, int len)
{
    if (!isVaildPtr(addr)) return false;

    kern_return_t kr = vm_write(
        get_task,
        (vm_address_t)addr,
        (vm_offset_t)buffer,
        (mach_msg_type_number_t)len
    );

    if (kr != KERN_SUCCESS) {
        return false;
    }
    return true;
}
