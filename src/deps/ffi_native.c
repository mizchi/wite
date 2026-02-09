#include <stdlib.h>
#include "moonbit.h"

#ifdef _WIN32
#include <process.h>
#else
#include <sys/wait.h>
#endif

MOONBIT_FFI_EXPORT int wite_system_ffi(moonbit_bytes_t cmd) {
    int ret = system((const char *)cmd);
    if (ret == -1) return -1;
#ifdef _WIN32
    return ret;
#else
    if (WIFEXITED(ret)) return WEXITSTATUS(ret);
    return -1;
#endif
}
