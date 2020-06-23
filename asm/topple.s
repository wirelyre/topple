.intel_syntax noprefix

.globl _start
_start:

# rax: _(rdi, rsi, rdx, r10, r8, r9)
# 0: read(unsigned int fd, char *buf, size_t count)
# 1: write(unsigned int fd, const char *buf, size_t count)
# 2: open(const char *filename, int flags, int mode)
# 3: close(unsigned int fd)
# 60: exit(int error_code)

    mov eax, 60
    xor edi, edi
    syscall
