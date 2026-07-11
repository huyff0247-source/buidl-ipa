#import "MemoryUtils.h"
#import <mach-o/loader.h>
#import <mach-o/nlist.h>

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
        NSLog(@"[ESP] Khong tim thay process: %s", GameProcessName);
        return 0;
    }
    
    kern_return_t kret = task_for_pid(mach_task_self(), pid, &get_task);
    
    if (get_task == MACH_PORT_NULL) {
        NSLog(@"[ESP] task_for_pid that bai voi pid: %d", pid);
        return 0;
    }
    
    NSLog(@"[ESP] Tim module base cho: %s (pid=%d)", GameProcessName, pid);
    
    // Iterate qua tat ca memory regions de tim module freefireth
    while (1) {
        kern_return_t kr = mach_vm_region_recurse(get_task, &vmoffset, &vmsize, &nesting_depth, (vm_region_recurse_info_t)&vbr, &vbrcount);
        if (kr != KERN_SUCCESS) {
            break;
        }
        
        // Doc header cua region de kiem tra co phai Mach-O image khong
        struct mach_header_64 header;
        vm_size_t header_size = 0;
        kern_return_t read_kr = vm_read_overwrite(get_task, (vm_address_t)vmoffset, sizeof(header), (vm_address_t)&header, &header_size);
        
        if (read_kr == KERN_SUCCESS && header_size == sizeof(header)) {
            // Kiem tra magic number: MH_MAGIC_64 = 0xFEEDFACF
            if (header.magic == MH_MAGIC_64) {
                // Doc ten module tu LC_ID_DYLIB hoac LC_ID_EXECUTABLE
                // Don gian: kiem tra ten process co chua "freefireth" khong
                // Vi Mach-O khong luu ten module truc tiep, ta can dung cach khac
                
                // Cach 1: Kiem tra region dau tien (thuong la __TEXT segment cua main executable)
                // Cach 2: Dung dyld info de lay ten
                
                // Don gian nhat: lay region dau tien co MH_MAGIC_64
                // Vi freefireth la main executable, region dau tien thuong la base
                NSLog(@"[ESP] Tim thay Mach-O image tai: 0x%llx (size=0x%llx)", vmoffset, vmsize);
                return vmoffset;
            }
        }
        
        vmoffset += vmsize;
    }
    
    NSLog(@"[ESP] Khong tim thay module base");
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
