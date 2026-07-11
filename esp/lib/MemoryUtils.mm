#import "MemoryUtils.h"
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>


// libproc.h khong co trong iOS SDK -> tu khai bao proc_pidpath.
// Ham nay van ton tai trong libSystem luc runtime tren iOS.
#ifndef PROC_PIDPATHINFO_MAXSIZE
#define PROC_PIDPATHINFO_MAXSIZE (4 * 1024)
#endif
extern "C" int proc_pidpath(int pid, void *buffer, uint32_t buffersize);

// Bundle ID cua Free Fire (xac dinh game chac chan qua bundle id)
#define FF_BUNDLE_ID "com.dts.freefireth"

// Ghi log vao file de debug.
// Ghi vao Documents cua app (luon ghi duoc) va thu /var/mobile/Documents.
void ESPLog(const char *format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    // 1) NSLog ra syslog (xem bang Console.app / idevicesyslog)
    NSLog(@"[ESP] %s", buffer);

    // 2) Ghi vao Documents cua chinh app (khong bi sandbox chan)
    static NSString *logPath = nil;
    if (logPath == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            logPath = [[paths firstObject] stringByAppendingPathComponent:@"esp_log.txt"];
        }
    }

    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char timeStr[26];
    strftime(timeStr, 26, "%Y-%m-%d %H:%M:%S", tm_info);

    if (logPath) {
        FILE *fp = fopen([logPath UTF8String], "a");
        if (fp) {
            fprintf(fp, "[%s] %s\n", timeStr, buffer);
            fclose(fp);
        }
    }

    // 3) Thu ghi them vao /var/mobile/Documents (neu co quyen)
    FILE *fp2 = fopen("/var/mobile/Documents/esp_log.txt", "a");
    if (fp2) {
        fprintf(fp2, "[%s] %s\n", timeStr, buffer);
        fclose(fp2);
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

// Ghi ra log tat ca process dang chay (de debug khi khong tim thay game)
void LogAllProcesses(void) {
    size_t length = 0;
    static const int name[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    if (sysctl((int *)name, (sizeof(name)/sizeof(*name)) - 1, NULL, &length, NULL, 0) != 0) return;
    struct kinfo_proc *buf = (struct kinfo_proc *)malloc(length);
    if (!buf) return;
    if (sysctl((int *)name, (sizeof(name)/sizeof(*name)) - 1, buf, &length, NULL, 0) != 0) { free(buf); return; }
    int count = (int)length / sizeof(struct kinfo_proc);
    ESPLog("LogAllProcesses: tong %d process", count);
    for (int i = 0; i < count; ++i) {
        pid_t p = buf[i].kp_proc.p_pid;
        char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
        proc_pidpath(p, path, sizeof(path));
        ESPLog("  pid=%d comm='%s' path='%s'", p, buf[i].kp_proc.p_comm, path);
    }
    free(buf);
}

// Tim pid cua game qua BUNDLE ID (chinh xac nhat).
// Lay duong dan bundle tu LSApplicationProxy roi so voi proc_pidpath cua tung process.
pid_t GetGamePidByBundle(const char *bundleId) {
    @autoreleasepool {
        // Goi qua runtime de KHONG can link them framework (MobileCoreServices).
        Class proxyCls = NSClassFromString(@"LSApplicationProxy");
        NSString *bundlePath = nil;
        if (proxyCls) {
            id proxy = [proxyCls performSelector:@selector(applicationProxyForIdentifier:)
                                      withObject:[NSString stringWithUTF8String:bundleId]];
            NSURL *url = [proxy bundleURL];
            bundlePath = url.path;
        }
        if (bundlePath.length == 0) {
            ESPLog("GetGamePidByBundle: khong lay duoc bundleURL cho %s (LSApplicationProxy=%p)", bundleId, proxyCls);
            return -1;
        }
        ESPLog("GetGamePidByBundle: bundlePath='%s'", [bundlePath UTF8String]);

        size_t length = 0;
        static const int name[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        if (sysctl((int *)name, (sizeof(name)/sizeof(*name)) - 1, NULL, &length, NULL, 0) != 0) return -1;
        struct kinfo_proc *buf = (struct kinfo_proc *)malloc(length);
        if (!buf) return -1;
        if (sysctl((int *)name, (sizeof(name)/sizeof(*name)) - 1, buf, &length, NULL, 0) != 0) { free(buf); return -1; }

        int count = (int)length / sizeof(struct kinfo_proc);
        const char *bp = [bundlePath UTF8String];
        pid_t found = -1;
        for (int i = 0; i < count; ++i) {
            pid_t p = buf[i].kp_proc.p_pid;
            char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
            if (proc_pidpath(p, path, sizeof(path)) > 0) {
                // process path thuong la .../<App>.app/<exe> -> nam trong thu muc bundle
                if (strstr(path, bp) != NULL) {
                    ESPLog("GetGamePidByBundle: MATCH pid=%d path='%s'", p, path);
                    found = p;
                    break;
                }
            }
        }
        free(buf);
        if (found == -1) ESPLog("GetGamePidByBundle: khong co process nao khop bundle path");
        return found;
    }
}

// Ly do that bai gan nhat, hien tren HUD
char g_baseErr[256] = "";

vm_map_offset_t GetGameModule_Base(char* GameProcessName) {
    vm_map_offset_t vmoffset = 0;
    vm_map_size_t vmsize = 0;
    uint32_t nesting_depth = 0;
    struct vm_region_submap_info_64 vbr;
    mach_msg_type_number_t vbrcount = 16;

    // Thu nhieu ten process co the co cua Free Fire
    static const char *candidates[] = {
        "freefireth", "freefire", "GameAssembly", "UnityFramework"
    };

    // 1) Uu tien: tim chinh xac theo BUNDLE ID com.dts.freefireth
    pid_t pid = GetGamePidByBundle(FF_BUNDLE_ID);

    // 2) Fallback: tim theo ten process (comm)
    if (pid == -1) {
        pid = GetGameProcesspid(GameProcessName);
    }
    if (pid == -1) {
        for (size_t i = 0; i < sizeof(candidates)/sizeof(candidates[0]); ++i) {
            pid = GetGameProcesspid((char*)candidates[i]);
            if (pid != -1) {
                ESPLog("GetGameModule_Base: Tim thay bang ten thay the '%s' pid=%d", candidates[i], pid);
                break;
            }
        }
    }

    if (pid == -1) {
        ESPLog("GetGameModule_Base: Khong tim thay process (bundle=%s, comm=%s). Liet ke tat ca process:", FF_BUNDLE_ID, GameProcessName);
        LogAllProcesses();
        snprintf(g_baseErr, sizeof(g_baseErr), "NOT FOUND bundle=%s (game chua mo?) - xem esp_log.txt", FF_BUNDLE_ID);
        return 0;
    }

    ESPLog("GetGameModule_Base: Tim thay pid=%d cho %s", pid, GameProcessName);

    get_task = MACH_PORT_NULL;
    kern_return_t kret = task_for_pid(mach_task_self(), pid, &get_task);

    if (kret != KERN_SUCCESS || get_task == MACH_PORT_NULL) {
        ESPLog("GetGameModule_Base: task_for_pid that bai kret=%d (thieu quyen task_for_pid-allow)", kret);
        snprintf(g_baseErr, sizeof(g_baseErr), "task_for_pid FAIL kret=%d (thieu quyen)", kret);
        return 0;
    }

    kern_return_t kr = mach_vm_region_recurse(get_task, &vmoffset, &vmsize, &nesting_depth, (vm_region_recurse_info_t)&vbr, &vbrcount);
    if (kr == KERN_SUCCESS) {
        ESPLog("GetGameModule_Base: Module base = 0x%llx (size=0x%llx) pid=%d", vmoffset, vmsize, pid);
        snprintf(g_baseErr, sizeof(g_baseErr), "OK pid=%d base=0x%llx", pid, (unsigned long long)vmoffset);
        return vmoffset;
    }

    ESPLog("GetGameModule_Base: mach_vm_region_recurse that bai: %d", kr);
    snprintf(g_baseErr, sizeof(g_baseErr), "vm_region_recurse FAIL kr=%d", kr);
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
