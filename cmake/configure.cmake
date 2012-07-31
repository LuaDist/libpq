# Copyright (C) 2009 Sun Microsystems,Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

include ( CheckCSourceCompiles )
include ( CheckCXXSourceCompiles )
include ( CheckStructHasMember )
include ( CheckLibraryExists )
include ( CheckFunctionExists )
include ( CheckCCompilerFlag )
include ( CheckCSourceRuns )
include ( CheckSymbolExists )

# WITH_PIC options.Not of much use, PIC is taken care of on platforms
# where it makes sense anyway.
if ( UNIX )
  if ( APPLE )
    # OSX  executable are always PIC
    set ( WITH_PIC ON )
  else ( )
    option ( WITH_PIC "Generate PIC objects" OFF )
    if ( WITH_PIC )
      set ( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CMAKE_SHARED_LIBRARY_C_FLAGS}" )
      set ( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_SHARED_LIBRARY_CXX_FLAGS}" )
    endif ( )
  endif ( )
endif ( )

# System type affects version_compile_os variable 
if ( NOT SYSTEM_TYPE )
  if ( PLATFORM )
    set ( SYSTEM_TYPE ${PLATFORM} )
  else ( )
    set ( SYSTEM_TYPE ${CMAKE_SYSTEM_NAME} )
  endif ( )
endif ( )

# Always enable -Wall for gnu C/C++
if ( CMAKE_COMPILER_IS_GNUCXX )
  set ( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wno-unused-parameter" )
endif ( )
if ( CMAKE_COMPILER_IS_GNUCC )
  set ( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall" )
endif ( )

if ( CMAKE_COMPILER_IS_GNUCXX )
  # MySQL "canonical" GCC flags. At least -fno-rtti flag affects
  # ABI and cannot be simply removed. 
  set ( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-implicit-templates -fno-exceptions -fno-rtti" )
  if ( CMAKE_CXX_FLAGS )
    string ( REGEX MATCH "fno-implicit-templates" NO_IMPLICIT_TEMPLATES ${CMAKE_CXX_FLAGS} )
    if ( NO_IMPLICIT_TEMPLATES )
      set ( HAVE_EXPLICIT_TEMPLATE_INSTANTIATION TRUE )
    endif ( )
  endif ( )

  if ( CMAKE_EXE_LINKER_FLAGS MATCHES " -static " OR CMAKE_EXE_LINKER_FLAGS MATCHES 
    " -static$" )
    set ( HAVE_DLOPEN FALSE CACHE "Disable dlopen due to -static flag" FORCE )
    set ( WITHOUT_DYNAMIC_PLUGINS TRUE )
  endif ( )
endif ( )

if ( WITHOUT_DYNAMIC_PLUGINS )
  message ( "Dynamic plugins are disabled." )
endif ( WITHOUT_DYNAMIC_PLUGINS )

# Large files, common flag
set ( _LARGEFILE_SOURCE 1 )

# If finds the size of a type, set SIZEOF_&lt;type&gt; and HAVE_&lt;type&gt;
function ( MY_CHECK_TYPE_SIZE type defbase )
  check_type_size ( "${type}" SIZEOF_${defbase} )
  if ( SIZEOF_${defbase} )
    set ( HAVE_${defbase} 1 PARENT_SCOPE )
  endif ( )
endfunction ( )

# Same for structs, setting HAVE_STRUCT_&lt;name&gt; instead
function ( MY_CHECK_STRUCT_SIZE type defbase )
  check_type_size ( "struct ${type}" SIZEOF_${defbase} )
  if ( SIZEOF_${defbase} )
    set ( HAVE_STRUCT_${defbase} 1 PARENT_SCOPE )
  endif ( )
endfunction ( )

# Searches function in libraries
# if function is found, sets output parameter result to the name of the library
# if function is found in libc, result will be empty 
function ( MY_SEARCH_LIBS func libs result )
  if ( ${${result}} )
    # Library is already found or was predefined
    return ( )
  endif ( )
  check_function_exists ( ${func} HAVE_${func}_IN_LIBC )
  if ( HAVE_${func}_IN_LIBC )
    set ( ${result} "" PARENT_SCOPE )
    return ( )
  endif ( )
  foreach ( lib ${libs} )
  check_library_exists ( ${lib} ${func} "" HAVE_${func}_IN_${lib} )
  if ( HAVE_${func}_IN_${lib} )
    set ( ${result} ${lib} PARENT_SCOPE )
    set ( HAVE_${result} 1 PARENT_SCOPE )
    return ( )
  endif ( )
  endforeach ( )
endfunction ( )

# Find out which libraries to use.
if ( UNIX )
  my_search_libs ( floor m LIBM )
  if ( NOT LIBM )
    my_search_libs ( __infinity m LIBM )
  endif ( )
  my_search_libs ( gethostbyname_r "nsl_r;nsl" LIBNSL )
  my_search_libs ( bind "bind;socket" LIBBIND )
  my_search_libs ( crypt crypt LIBCRYPT )
  my_search_libs ( setsockopt socket LIBSOCKET )
  my_search_libs ( dlopen dl LIBDL )
  my_search_libs ( sched_yield rt LIBRT )
  if ( NOT LIBRT )
    my_search_libs ( clock_gettime rt LIBRT )
  endif ( )
  find_package ( Threads )

  set ( CMAKE_REQUIRED_LIBRARIES ${LIBM} ${LIBNSL} ${LIBBIND} ${LIBCRYPT} ${LIBSOCKET} 
    ${LIBDL} ${CMAKE_THREAD_LIBS_INIT} ${LIBRT} )

  if ( CMAKE_REQUIRED_LIBRARIES )
    list ( REMOVE_DUPLICATES CMAKE_REQUIRED_LIBRARIES )
  endif ( )

  link_libraries ( ${CMAKE_THREAD_LIBS_INIT} )
  option ( WITH_LIBWRAP "Compile with tcp wrappers support" OFF )
  if ( WITH_LIBWRAP )
    set ( SAVE_CMAKE_REQUIRED_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES} )
    set ( CMAKE_REQUIRED_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES} wrap )
    check_c_source_compiles ( " #include &lt;tcpd.h&gt; int allow_severity = 0; int deny_severity = 0; int main() { hosts_access(0); }" 
      HAVE_LIBWRAP )
    set ( CMAKE_REQUIRED_LIBRARIES ${SAVE_CMAKE_REQUIRED_LIBRARIES} )
    if ( HAVE_LIBWRAP )
      set ( MYSYS_LIBWRAP_SOURCE ${CMAKE_SOURCE_DIR}/mysys/my_libwrap.c )
      set ( LIBWRAP "wrap" )
    endif ( )
  endif ( )
endif ( )

#
# Tests for header files
#
include ( CheckIncludeFiles )

check_include_files ( "stdlib.h;stdarg.h;string.h;float.h" STDC_HEADERS )
check_include_files ( sys/types.h HAVE_SYS_TYPES_H )
check_include_files ( alloca.h HAVE_ALLOCA_H )
check_include_files ( aio.h HAVE_AIO_H )
check_include_files ( arpa/inet.h HAVE_ARPA_INET_H )
check_include_files ( crypt.h HAVE_CRYPT_H )
check_include_files ( cxxabi.h HAVE_CXXABI_H )
check_include_files ( dirent.h HAVE_DIRENT_H )
check_include_files ( dlfcn.h HAVE_DLFCN_H )
check_include_files ( execinfo.h HAVE_EXECINFO_H )
check_include_files ( fcntl.h HAVE_FCNTL_H )
check_include_files ( fenv.h HAVE_FENV_H )
check_include_files ( float.h HAVE_FLOAT_H )
check_include_files ( floatingpoint.h HAVE_FLOATINGPOINT_H )
check_include_files ( fpu_control.h HAVE_FPU_CONTROL_H )
check_include_files ( grp.h HAVE_GRP_H )
check_include_files ( ieeefp.h HAVE_IEEEFP_H )
check_include_files ( inttypes.h HAVE_INTTYPES_H )
check_include_files ( langinfo.h HAVE_LANGINFO_H )
check_include_files ( limits.h HAVE_LIMITS_H )
check_include_files ( locale.h HAVE_LOCALE_H )
check_include_files ( malloc.h HAVE_MALLOC_H )
check_include_files ( memory.h HAVE_MEMORY_H )
check_include_files ( ndir.h HAVE_NDIR_H )
check_include_files ( netinet HAVE_NETINET_IN_H )
check_include_files ( paths.h HAVE_PATHS_H )
check_include_files ( port.h HAVE_PORT_H )
check_include_files ( poll.h HAVE_POLL_H )
check_include_files ( pwd.h HAVE_PWD_H )
check_include_files ( sched.h HAVE_SCHED_H )
check_include_files ( select.h HAVE_SELECT_H )
check_include_files ( semaphore.h HAVE_SEMAPHORE_H )
check_include_files ( "sys/types.h;sys/dir.h" HAVE_SYS_DIR_H )
check_include_files ( sys/ndir.h HAVE_SYS_NDIR_H )
check_include_files ( sys/pte.h HAVE_SYS_PTE_H )
check_include_files ( stddef.h HAVE_STDDEF_H )
check_include_files ( stdint.h HAVE_STDINT_H )
check_include_files ( stdlib.h HAVE_STDLIB_H )
check_include_files ( strings.h HAVE_STRINGS_H )
check_include_files ( string.h HAVE_STRING_H )
check_include_files ( synch.h HAVE_SYNCH_H )
check_include_files ( sysent.h HAVE_SYSENT_H )
check_include_files ( sys/cdefs.h HAVE_SYS_CDEFS_H )
check_include_files ( sys/file.h HAVE_SYS_FILE_H )
check_include_files ( sys/fpu.h HAVE_SYS_FPU_H )
check_include_files ( sys/ioctl.h HAVE_SYS_IOCTL_H )
check_include_files ( sys/ipc.h HAVE_SYS_IPC_H )
check_include_files ( sys/malloc.h HAVE_SYS_MALLOC_H )
check_include_files ( sys/mman.h HAVE_SYS_MMAN_H )
check_include_files ( sys/prctl.h HAVE_SYS_PRCTL_H )
check_include_files ( sys/resource.h HAVE_SYS_RESOURCE_H )
check_include_files ( sys/select.h HAVE_SYS_SELECT_H )
check_include_files ( sys/shm.h HAVE_SYS_SHM_H )
check_include_files ( sys/socket.h HAVE_SYS_SOCKET_H )
check_include_files ( sys/stat.h HAVE_SYS_STAT_H )
check_include_files ( sys/stream.h HAVE_SYS_STREAM_H )
check_include_files ( sys/termcap.h HAVE_SYS_TERMCAP_H )
check_include_files ( "time.h;sys/timeb.h" HAVE_SYS_TIMEB_H )
check_include_files ( "curses.h;term.h" HAVE_TERM_H )
check_include_files ( asm/termbits.h HAVE_ASM_TERMBITS_H )
check_include_files ( termbits.h HAVE_TERMBITS_H )
check_include_files ( termios.h HAVE_TERMIOS_H )
check_include_files ( termio.h HAVE_TERMIO_H )
check_include_files ( termcap.h HAVE_TERMCAP_H )
check_include_files ( unistd.h HAVE_UNISTD_H )
check_include_files ( utime.h HAVE_UTIME_H )
check_include_files ( varargs.h HAVE_VARARGS_H )
check_include_files ( sys/time.h HAVE_SYS_TIME_H )
check_include_files ( sys/utime.h HAVE_SYS_UTIME_H )
check_include_files ( sys/wait.h HAVE_SYS_WAIT_H )
check_include_files ( sys/param.h HAVE_SYS_PARAM_H )
check_include_files ( sys/vadvise.h HAVE_SYS_VADVISE_H )
check_include_files ( fnmatch.h HAVE_FNMATCH_H )
check_include_files ( stdarg.h HAVE_STDARG_H )
check_include_files ( "stdlib.h;sys/un.h" HAVE_SYS_UN_H )
check_include_files ( vis.h HAVE_VIS_H )
check_include_files ( wchar.h HAVE_WCHAR_H )
check_include_files ( wctype.h HAVE_WCTYPE_H )
check_include_files ( net/if.h HAVE_NET_IF_H )

if ( HAVE_SYS_STREAM_H )
  # Needs sys/stream.h on Solaris
  check_include_files ( "sys/stream.h;sys/ptem.h" HAVE_SYS_PTEM_H )
else ( )
  check_include_files ( sys/ptem.h HAVE_SYS_PTEM_H )
endif ( )

# Figure out threading library
#
find_package ( Threads )

#
# Tests for functions
#
#CHECK_FUNCTION_EXISTS (aiowait HAVE_AIOWAIT)
check_function_exists ( aio_read HAVE_AIO_READ )
check_function_exists ( alarm HAVE_ALARM )
set ( HAVE_ALLOCA 1 )
check_function_exists ( backtrace HAVE_BACKTRACE )
check_function_exists ( backtrace_symbols HAVE_BACKTRACE_SYMBOLS )
check_function_exists ( backtrace_symbols_fd HAVE_BACKTRACE_SYMBOLS_FD )
check_function_exists ( printstack HAVE_PRINTSTACK )
check_function_exists ( bfill HAVE_BFILL )
check_function_exists ( bmove HAVE_BMOVE )
check_function_exists ( bsearch HAVE_BSEARCH )
check_function_exists ( index HAVE_INDEX )
check_function_exists ( bzero HAVE_BZERO )
check_function_exists ( clock_gettime HAVE_CLOCK_GETTIME )
check_function_exists ( cuserid HAVE_CUSERID )
check_function_exists ( directio HAVE_DIRECTIO )
check_function_exists ( _doprnt HAVE_DOPRNT )
check_function_exists ( flockfile HAVE_FLOCKFILE )
check_function_exists ( ftruncate HAVE_FTRUNCATE )
check_function_exists ( getline HAVE_GETLINE )
check_function_exists ( compress HAVE_COMPRESS )
check_function_exists ( crypt HAVE_CRYPT )
check_function_exists ( dlerror HAVE_DLERROR )
check_function_exists ( dlopen HAVE_DLOPEN )
check_function_exists ( fchmod HAVE_FCHMOD )
check_function_exists ( fcntl HAVE_FCNTL )
check_function_exists ( fconvert HAVE_FCONVERT )
check_function_exists ( fdatasync HAVE_FDATASYNC )
check_symbol_exists ( fdatasync "unistd.h" HAVE_DECL_FDATASYNC )
check_function_exists ( fesetround HAVE_FESETROUND )
check_function_exists ( fpsetmask HAVE_FPSETMASK )
check_function_exists ( fseeko HAVE_FSEEKO )
check_function_exists ( fsync HAVE_FSYNC )
check_function_exists ( getcwd HAVE_GETCWD )
check_function_exists ( gethostbyaddr_r HAVE_GETHOSTBYADDR_R )
check_function_exists ( gethostbyname_r HAVE_GETHOSTBYNAME_R )
check_function_exists ( gethrtime HAVE_GETHRTIME )
check_function_exists ( getnameinfo HAVE_GETNAMEINFO )
check_function_exists ( getpass HAVE_GETPASS )
check_function_exists ( getpassphrase HAVE_GETPASSPHRASE )
check_function_exists ( getpwnam HAVE_GETPWNAM )
check_function_exists ( getpwuid HAVE_GETPWUID )
check_function_exists ( getrlimit HAVE_GETRLIMIT )
check_function_exists ( getrusage HAVE_GETRUSAGE )
check_function_exists ( getwd HAVE_GETWD )
check_function_exists ( gmtime_r HAVE_GMTIME_R )
check_function_exists ( initgroups HAVE_INITGROUPS )
check_function_exists ( issetugid HAVE_ISSETUGID )
check_function_exists ( ldiv HAVE_LDIV )
check_function_exists ( localtime_r HAVE_LOCALTIME_R )
check_function_exists ( longjmp HAVE_LONGJMP )
check_function_exists ( lstat HAVE_LSTAT )
check_function_exists ( madvise HAVE_MADVISE )
check_function_exists ( mallinfo HAVE_MALLINFO )
check_function_exists ( memcpy HAVE_MEMCPY )
check_function_exists ( memmove HAVE_MEMMOVE )
check_function_exists ( mkstemp HAVE_MKSTEMP )
check_function_exists ( mlock HAVE_MLOCK )
check_function_exists ( mlockall HAVE_MLOCKALL )
check_function_exists ( mmap HAVE_MMAP )
check_function_exists ( mmap64 HAVE_MMAP64 )
check_function_exists ( perror HAVE_PERROR )
check_function_exists ( poll HAVE_POLL )
check_function_exists ( port_create HAVE_PORT_CREATE )
check_function_exists ( posix_fallocate HAVE_POSIX_FALLOCATE )
check_function_exists ( pread HAVE_PREAD )
check_function_exists ( pthread_attr_create HAVE_PTHREAD_ATTR_CREATE )
check_function_exists ( pthread_attr_getstacksize HAVE_PTHREAD_ATTR_GETSTACKSIZE )
check_function_exists ( pthread_attr_setscope HAVE_PTHREAD_ATTR_SETSCOPE )
check_function_exists ( pthread_attr_setstacksize HAVE_PTHREAD_ATTR_SETSTACKSIZE )
check_function_exists ( pthread_condattr_create HAVE_PTHREAD_CONDATTR_CREATE )
check_function_exists ( pthread_condattr_setclock HAVE_PTHREAD_CONDATTR_SETCLOCK )
check_function_exists ( pthread_init HAVE_PTHREAD_INIT )
check_function_exists ( pthread_key_delete HAVE_PTHREAD_KEY_DELETE )
check_function_exists ( pthread_rwlock_rdlock HAVE_PTHREAD_RWLOCK_RDLOCK )
check_function_exists ( pthread_sigmask HAVE_PTHREAD_SIGMASK )
check_function_exists ( pthread_threadmask HAVE_PTHREAD_THREADMASK )
check_function_exists ( pthread_yield_np HAVE_PTHREAD_YIELD_NP )
check_function_exists ( putenv HAVE_PUTENV )
check_function_exists ( readdir_r HAVE_READDIR_R )
check_function_exists ( readlink HAVE_READLINK )
check_function_exists ( re_comp HAVE_RE_COMP )
check_function_exists ( regcomp HAVE_REGCOMP )
check_function_exists ( realpath HAVE_REALPATH )
check_function_exists ( rename HAVE_RENAME )
check_function_exists ( rwlock_init HAVE_RWLOCK_INIT )
check_function_exists ( sched_yield HAVE_SCHED_YIELD )
check_function_exists ( setenv HAVE_SETENV )
check_function_exists ( setlocale HAVE_SETLOCALE )
check_function_exists ( setfd HAVE_SETFD )
check_function_exists ( sigaction HAVE_SIGACTION )
check_function_exists ( sigthreadmask HAVE_SIGTHREADMASK )
check_function_exists ( sigwait HAVE_SIGWAIT )
check_function_exists ( sigaddset HAVE_SIGADDSET )
check_function_exists ( sigemptyset HAVE_SIGEMPTYSET )
check_function_exists ( sighold HAVE_SIGHOLD )
check_function_exists ( sigset HAVE_SIGSET )
check_function_exists ( sleep HAVE_SLEEP )
check_function_exists ( snprintf HAVE_SNPRINTF )
check_function_exists ( stpcpy HAVE_STPCPY )
check_function_exists ( strcoll HAVE_STRCOLL )
check_function_exists ( strerror HAVE_STRERROR )
check_function_exists ( strlcpy HAVE_STRLCPY )
check_function_exists ( strnlen HAVE_STRNLEN )
check_function_exists ( strlcat HAVE_STRLCAT )
check_function_exists ( strsignal HAVE_STRSIGNAL )
check_function_exists ( fgetln HAVE_FGETLN )
check_function_exists ( strpbrk HAVE_STRPBRK )
check_function_exists ( strsep HAVE_STRSEP )
check_function_exists ( strstr HAVE_STRSTR )
check_function_exists ( strtok_r HAVE_STRTOK_R )
check_function_exists ( strtol HAVE_STRTOL )
check_function_exists ( strtoll HAVE_STRTOLL )
check_function_exists ( strtoul HAVE_STRTOUL )
check_function_exists ( strtoull HAVE_STRTOULL )
check_function_exists ( strcasecmp HAVE_STRCASECMP )
check_function_exists ( strncasecmp HAVE_STRNCASECMP )
check_function_exists ( strdup HAVE_STRDUP )
check_function_exists ( shmat HAVE_SHMAT )
check_function_exists ( shmctl HAVE_SHMCTL )
check_function_exists ( shmdt HAVE_SHMDT )
check_function_exists ( shmget HAVE_SHMGET )
check_function_exists ( tell HAVE_TELL )
check_function_exists ( tempnam HAVE_TEMPNAM )
check_function_exists ( thr_setconcurrency HAVE_THR_SETCONCURRENCY )
check_function_exists ( thr_yield HAVE_THR_YIELD )
check_function_exists ( vasprintf HAVE_VASPRINTF )
check_function_exists ( vsnprintf HAVE_VSNPRINTF )
check_function_exists ( vprintf HAVE_VPRINTF )
check_function_exists ( valloc HAVE_VALLOC )
check_function_exists ( memalign HAVE_MEMALIGN )
check_function_exists ( chown HAVE_CHOWN )
check_function_exists ( nl_langinfo HAVE_NL_LANGINFO )
check_function_exists ( snprintf HAVE_DECL_SNPRINTF )
check_function_exists ( vsnprintf HAVE_DECL_VSNPRINTF )
check_function_exists ( unsetenv HAVE_UNSETENV )

#--------------------------------------------------------------------
# Support for WL#2373 (Use cycle counter for timing)
#--------------------------------------------------------------------

check_include_files ( time.h HAVE_TIME_H )
check_include_files ( sys/time.h HAVE_SYS_TIME_H )
check_include_files ( sys/times.h HAVE_SYS_TIMES_H )
check_include_files ( asm/msr.h HAVE_ASM_MSR_H )
#msr.h has rdtscll()

check_include_files ( ia64intrin.h HAVE_IA64INTRIN_H )

check_function_exists ( times HAVE_TIMES )
check_function_exists ( gettimeofday HAVE_GETTIMEOFDAY )
check_function_exists ( read_real_time HAVE_READ_REAL_TIME )
# This should work on AIX.

check_function_exists ( ftime HAVE_FTIME )
# This is still a normal call for milliseconds.

check_function_exists ( time HAVE_TIME )
# We can use time() on Macintosh if there is no ftime().

check_function_exists ( rdtscll HAVE_RDTSCLL )
# I doubt that we'll ever reach the check for this.

#
# Tests for symbols
#

check_symbol_exists ( sys_errlist "stdio.h" HAVE_SYS_ERRLIST )
check_symbol_exists ( madvise "sys/mman.h" HAVE_DECL_MADVISE )
check_symbol_exists ( tzname "time.h" HAVE_TZNAME )
check_symbol_exists ( lrand48 "stdlib.h" HAVE_LRAND48 )
check_symbol_exists ( getpagesize "unistd.h" HAVE_GETPAGESIZE )
check_symbol_exists ( TIOCGWINSZ "sys/ioctl.h" GWINSZ_IN_SYS_IOCTL )
check_symbol_exists ( FIONREAD "sys/ioctl.h" FIONREAD_IN_SYS_IOCTL )
check_symbol_exists ( TIOCSTAT "sys/ioctl.h" TIOCSTAT_IN_SYS_IOCTL )
check_symbol_exists ( gettimeofday "sys/time.h" HAVE_GETTIMEOFDAY )

check_symbol_exists ( finite "math.h" HAVE_FINITE_IN_MATH_H )
if ( HAVE_FINITE_IN_MATH_H )
  set ( HAVE_FINITE TRUE CACHE INTERNAL "" )
else ( )
  check_symbol_exists ( finite "ieeefp.h" HAVE_FINITE )
endif ( )
check_symbol_exists ( log2 math.h HAVE_LOG2 )
check_symbol_exists ( isnan math.h HAVE_ISNAN )
check_symbol_exists ( rint math.h HAVE_RINT )

# isinf() prototype not found on Solaris
check_cxx_source_compiles ( "#include &lt;math.h&gt; int main() { isinf(0.0); return 0; }" 
  HAVE_ISINF )

#
# Test for endianess
#
include ( TestBigEndian )
if ( APPLE )
  # Cannot run endian test on universal PPC/Intel binaries 
  # would return inconsistent result.
  # config.h.cmake includes a special #ifdef for Darwin
else ( )
  test_big_endian ( WORDS_BIGENDIAN )
endif ( )

#
# Tests for type sizes (and presence)
#
include ( CheckTypeSize )
set ( CMAKE_REQUIRED_DEFINITIONS ${CMAKE_REQUIRED_DEFINITIONS} -D_LARGEFILE_SOURCE 
  -D_LARGE_FILES -D_FILE_OFFSET_BITS=64 -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS 
  -D__STDC_FORMAT_MACROS )
set ( CMAKE_EXTRA_INCLUDE_FILES signal.h )
my_check_type_size ( sigset_t SIGSET_T )
if ( NOT SIZEOF_SIGSET_T )
  set ( sigset_t int )
endif ( )
my_check_type_size ( mode_t MODE_T )
if ( NOT SIZEOF_MODE_T )
  set ( mode_t int )
endif ( )

if ( HAVE_STDINT_H )
  set ( CMAKE_EXTRA_INCLUDE_FILES stdint.h )
endif ( HAVE_STDINT_H )

set ( HAVE_VOIDP 1 )
set ( HAVE_CHARP 1 )
set ( HAVE_LONG 1 )
set ( HAVE_SIZE_T 1 )

if ( NOT APPLE )
  my_check_type_size ( "void *" VOIDP )
  my_check_type_size ( "char *" CHARP )
  my_check_type_size ( long LONG )
  my_check_type_size ( size_t SIZE_T )
endif ( )

my_check_type_size ( char CHAR )
my_check_type_size ( short SHORT )
my_check_type_size ( int INT )
my_check_type_size ( "long long" LONG_LONG )
set ( CMAKE_EXTRA_INCLUDE_FILES stdio.h sys/types.h )
my_check_type_size ( off_t OFF_T )
my_check_type_size ( uchar UCHAR )
my_check_type_size ( uint UINT )
my_check_type_size ( ulong ULONG )
my_check_type_size ( int8 INT8 )
my_check_type_size ( uint8 UINT8 )
my_check_type_size ( int16 INT16 )
my_check_type_size ( uint16 UINT16 )
my_check_type_size ( int32 INT32 )
my_check_type_size ( uint32 UINT32 )
my_check_type_size ( u_int32_t U_INT32_T )
my_check_type_size ( int64 INT64 )
my_check_type_size ( uint64 UINT64 )
my_check_type_size ( "long int" LONG_INT_64 )
my_check_type_size ( "long long int" LONG_LONG_INT_64 )
set ( CMAKE_EXTRA_INCLUDE_FILES sys/types.h )
my_check_type_size ( bool BOOL )
set ( CMAKE_EXTRA_INCLUDE_FILES )

if ( HAVE_SYS_SOCKET_H )
  set ( CMAKE_EXTRA_INCLUDE_FILES sys/socket.h )
endif ( HAVE_SYS_SOCKET_H )
my_check_type_size ( socklen_t SOCKLEN_T )
set ( CMAKE_EXTRA_INCLUDE_FILES )

if ( HAVE_IEEEFP_H )
  set ( CMAKE_EXTRA_INCLUDE_FILES ieeefp.h )
  my_check_type_size ( fp_except FP_EXCEPT )
endif ( )

#
# Code tests
#

check_c_source_compiles ( " #ifdef _WIN32 #include &lt;winsock2.h&gt; #include &lt;ws2tcpip.h&gt; #else #include &lt;sys/types.h&gt; #include &lt;sys/socket.h&gt; #include &lt;netdb.h&gt; #endif int main() { getaddrinfo( 0, 0, 0, 0); return 0; }" 
  HAVE_GETADDRINFO )

check_c_source_compiles ( " #ifdef _WIN32 #include &lt;winsock2.h&gt; #include &lt;ws2tcpip.h&gt; #else #include &lt;sys/types.h&gt; #include &lt;sys/socket.h&gt; #include &lt;netdb.h&gt; #endif int main() { select(0,0,0,0,0); return 0; }" 
  HAVE_SELECT )

#
# Check if timespec has ts_sec and ts_nsec fields
#

check_c_source_compiles ( " #include &lt;pthread.h&gt; int main(int ac, char **av) { struct timespec abstime; abstime.ts_sec = time(NULL)+1; abstime.ts_nsec = 0; } " 
  HAVE_TIMESPEC_TS_SEC )

#
# Check return type of qsort()
#
check_c_source_compiles ( " #include &lt;stdlib.h&gt; #ifdef __cplusplus extern \"C\" #endif void qsort(void *base, size_t nel, size_t width, int (*compar) (const void *, const void *)); int main(int ac, char **av) {} " 
  QSORT_TYPE_IS_VOID )
if ( QSORT_TYPE_IS_VOID )
  set ( RETQSORTTYPE "void" )
else ( QSORT_TYPE_IS_VOID )
  set ( RETQSORTTYPE "int" )
endif ( QSORT_TYPE_IS_VOID )

if ( WIN32 )
  set ( SOCKET_SIZE_TYPE int )
else ( )
  check_cxx_source_compiles ( " #include &lt;sys/socket.h&gt; int main(int argc, char **argv) { getsockname(0,0,(socklen_t *) 0); return 0; }" 
    HAVE_SOCKET_SIZE_T_AS_socklen_t )

  if ( HAVE_SOCKET_SIZE_T_AS_socklen_t )
    set ( SOCKET_SIZE_TYPE socklen_t )
  else ( )
    check_cxx_source_compiles ( " #include &lt;sys/socket.h&gt; int main(int argc, char **argv) { getsockname(0,0,(int *) 0); return 0; }" 
      HAVE_SOCKET_SIZE_T_AS_int )
    if ( HAVE_SOCKET_SIZE_T_AS_int )
      set ( SOCKET_SIZE_TYPE int )
    else ( )
      check_cxx_source_compiles ( " #include &lt;sys/socket.h&gt; int main(int argc, char **argv) { getsockname(0,0,(size_t *) 0); return 0; }" 
        HAVE_SOCKET_SIZE_T_AS_size_t )
      if ( HAVE_SOCKET_SIZE_T_AS_size_t )
        set ( SOCKET_SIZE_TYPE size_t )
      else ( )
        set ( SOCKET_SIZE_TYPE int )
      endif ( )
    endif ( )
  endif ( )
endif ( )

check_cxx_source_compiles ( " #include &lt;pthread.h&gt; int main() { pthread_yield(); return 0; } " 
  HAVE_PTHREAD_YIELD_ZERO_ARG )

if ( NOT STACK_DIRECTION )
  if ( CMAKE_CROSSCOMPILING )
    message ( FATAL_ERROR "STACK_DIRECTION is not defined. Please specify -DSTACK_DIRECTION=1 " 
      "or -DSTACK_DIRECTION=-1 when calling cmake." )
  else ( )
    try_run ( STACKDIR_RUN_RESULT STACKDIR_COMPILE_RESULT ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/stack_direction.c )
    # Test program returns 0 (down) or 1 (up).
    # Convert to -1 or 1
    if ( STACKDIR_RUN_RESULT EQUAL 0 )
      set ( STACK_DIRECTION -1 CACHE INTERNAL "Stack grows direction" )
    else ( )
      set ( STACK_DIRECTION 1 CACHE INTERNAL "Stack grows direction" )
    endif ( )
    message ( STATUS "Checking stack direction : ${STACK_DIRECTION}" )
  endif ( )
endif ( )

#
# Check return type of signal handlers
#
check_c_source_compiles ( " #include &lt;signal.h&gt; #ifdef signal # undef signal #endif #ifdef __cplusplus extern \"C\" void (*signal (int, void (*)(int)))(int); #else void (*signal ()) (); #endif int main(int ac, char **av) {} " 
  SIGNAL_RETURN_TYPE_IS_VOID )
if ( SIGNAL_RETURN_TYPE_IS_VOID )
  set ( RETSIGTYPE void )
  set ( VOID_SIGHANDLER 1 )
else ( SIGNAL_RETURN_TYPE_IS_VOID )
  set ( RETSIGTYPE int )
endif ( SIGNAL_RETURN_TYPE_IS_VOID )

check_include_files ( "time.h;sys/time.h" TIME_WITH_SYS_TIME )
check_symbol_exists ( O_NONBLOCK "unistd.h;fcntl.h" HAVE_FCNTL_NONBLOCK )
if ( NOT HAVE_FCNTL_NONBLOCK )
  set ( NO_FCNTL_NONBLOCK 1 )
endif ( )

#
# Test for how the C compiler does inline, if at all
#
check_c_source_compiles ( " static inline int foo(){return 0;} int main(int argc, char *argv[]){return 0;}" 
  C_HAS_inline )
if ( NOT C_HAS_inline )
  check_c_source_compiles ( " static __inline int foo(){return 0;} int main(int argc, char *argv[]){return 0;}" 
    C_HAS___inline )
  set ( C_INLINE __inline )
endif ( )

if ( NOT CMAKE_CROSSCOMPILING AND NOT MSVC )
  string ( TOLOWER ${CMAKE_SYSTEM_PROCESSOR} processor )
  if ( processor MATCHES "86" OR processor MATCHES "amd64" OR processor MATCHES "x64" )
    #Check for x86 PAUSE instruction
    # We have to actually try running the test program, because of a bug
    # in Solaris on x86_64, where it wrongly reports that PAUSE is not
    # supported when trying to run an application.  See
    # http://bugs.opensolaris.org/bugdatabase/printableBug.do?bug_id=6478684
    check_c_source_runs ( " int main() { __asm__ __volatile__ (\"pause\"); return 0; }" 
      HAVE_PAUSE_INSTRUCTION )
  endif ( )
  if ( NOT HAVE_PAUSE_INSTRUCTION )
    check_c_source_compiles ( " int main() { __asm__ __volatile__ (\"rep; nop\"); return 0; } " 
      HAVE_FAKE_PAUSE_INSTRUCTION )
  endif ( )
endif ( )
check_symbol_exists ( tcgetattr "termios.h" HAVE_TCGETATTR 1 )

#
# Check type of signal routines (posix, 4.2bsd, 4.1bsd or v7)
#
check_c_source_compiles ( " #include &lt;signal.h&gt; int main(int ac, char **av) { sigset_t ss; struct sigaction sa; sigemptyset(&amp;ss); sigsuspend(&amp;ss); sigaction(SIGINT, &amp;sa, (struct sigaction *) 0); sigprocmask(SIG_BLOCK, &amp;ss, (sigset_t *) 0); }" 
  HAVE_POSIX_SIGNALS )

if ( NOT HAVE_POSIX_SIGNALS )
  check_c_source_compiles ( " #include &lt;signal.h&gt; int main(int ac, char **av) { int mask = sigmask(SIGINT); sigsetmask(mask); sigblock(mask); sigpause(mask); }" 
    HAVE_BSD_SIGNALS )
  if ( NOT HAVE_BSD_SIGNALS )
    check_c_source_compiles ( " #include &lt;signal.h&gt; void foo() { } int main(int ac, char **av) { int mask = sigmask(SIGINT); sigset(SIGINT, foo); sigrelse(SIGINT); sighold(SIGINT); sigpause(SIGINT); }" 
      HAVE_SVR3_SIGNALS )
    if ( NOT HAVE_SVR3_SIGNALS )
      set ( HAVE_V7_SIGNALS 1 )
    endif ( NOT HAVE_SVR3_SIGNALS )
  endif ( NOT HAVE_BSD_SIGNALS )
endif ( NOT HAVE_POSIX_SIGNALS )

# Assume regular sprintf
set ( SPRINTFS_RETURNS_INT 1 )

if ( CMAKE_COMPILER_IS_GNUCXX AND HAVE_CXXABI_H )
  check_cxx_source_compiles ( " #include &lt;cxxabi.h&gt; int main(int argc, char **argv) { char *foo= 0; int bar= 0; foo= abi::__cxa_demangle(foo, foo, 0, &amp;bar); return 0; }" 
    HAVE_ABI_CXA_DEMANGLE )
endif ( )

check_c_source_compiles ( " int main(int argc, char **argv) { extern char *__bss_start; return __bss_start ? 1 : 0; }" 
  HAVE_BSS_START )

check_c_source_compiles ( " int main() { extern void __attribute__((weak)) foo(void); return 0; }" 
  HAVE_WEAK_SYMBOL )

check_cxx_source_compiles ( " #include &lt;new&gt; int main() { char *c = new char; return 0; }" 
  HAVE_CXX_NEW )

check_cxx_source_compiles ( " #undef inline #if !defined(SCO) &amp;&amp; !defined(__osf__) &amp;&amp; !defined(_REENTRANT) #define _REENTRANT #endif #include &lt;pthread.h&gt; #include &lt;sys/types.h&gt; #include &lt;sys/socket.h&gt; #include &lt;netinet/in.h&gt; #include &lt;arpa/inet.h&gt; #include &lt;netdb.h&gt; int main() { struct hostent *foo = gethostbyaddr_r((const char *) 0, 0, 0, (struct hostent *) 0, (char *) NULL, 0, (int *)0); return 0; } " 
  HAVE_SOLARIS_STYLE_GETHOST )

check_cxx_source_compiles ( " #undef inline #if !defined(SCO) &amp;&amp; !defined(__osf__) &amp;&amp; !defined(_REENTRANT) #define _REENTRANT #endif #include &lt;pthread.h&gt; #include &lt;sys/types.h&gt; #include &lt;sys/socket.h&gt; #include &lt;netinet/in.h&gt; #include &lt;arpa/inet.h&gt; #include &lt;netdb.h&gt; int main() { int ret = gethostbyname_r((const char *) 0, 	(struct hostent*) 0, (char*) 0, 0, (struct hostent **) 0, (int *) 0); return 0; }" 
  HAVE_GETHOSTBYNAME_R_GLIBC2_STYLE )

check_cxx_source_compiles ( " #undef inline #if !defined(SCO) &amp;&amp; !defined(__osf__) &amp;&amp; !defined(_REENTRANT) #define _REENTRANT #endif #include &lt;pthread.h&gt; #include &lt;sys/types.h&gt; #include &lt;sys/socket.h&gt; #include &lt;netinet/in.h&gt; #include &lt;arpa/inet.h&gt; #include &lt;netdb.h&gt; int main() { int ret = gethostbyname_r((const char *) 0, (struct hostent*) 0, (struct hostent_data*) 0); return 0; }" 
  HAVE_GETHOSTBYNAME_R_RETURN_INT )

# Use of ALARMs to wakeup on timeout on sockets
#
# This feature makes use of a mutex and is a scalability hog we
# try to avoid using. However we need support for SO_SNDTIMEO and
# SO_RCVTIMEO socket options for this to work. So we will check
# if this feature is supported by a simple TRY_RUN macro. However
# on some OS's there is support for setting those variables but
# they are silently ignored. For those OS's we will not attempt
# to use SO_SNDTIMEO and SO_RCVTIMEO even if it is said to work.
# See Bug#29093 for the problem with SO_SND/RCVTIMEO on HP/UX.
# To use alarm is simple, simply avoid setting anything.

if ( WIN32 )
  set ( HAVE_SOCKET_TIMEOUT 1 )
elseif ( CMAKE_SYSTEM MATCHES "HP-UX" )
set ( HAVE_SOCKET_TIMEOUT 0 )
elseif ( CMAKE_CROSSCOMPILING )
set ( HAVE_SOCKET_TIMEOUT 0 )
else ( )
  set ( CMAKE_REQUIRED_LIBRARIES ${LIBNSL} ${LIBSOCKET} )
  check_c_source_runs ( " #include &lt;sys/types.h&gt; #include &lt;sys/socket.h&gt; #include &lt;sys/time.h&gt; int main() { int fd = socket(AF_INET, SOCK_STREAM, 0); struct timeval tv; int ret= 0; tv.tv_sec= 2; tv.tv_usec= 0; ret|= setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &amp;tv, sizeof(tv)); ret|= setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &amp;tv, sizeof(tv)); return !!ret; } " 
    HAVE_SOCKET_TIMEOUT )
endif ( )

set ( NO_ALARM "${HAVE_SOCKET_TIMEOUT}" CACHE BOOL "No need to use alarm to implement socket timeout" )
set ( SIGNAL_WITH_VIO_CLOSE "${HAVE_SOCKET_TIMEOUT}" )
mark_as_advanced ( NO_ALARM )

if ( CMAKE_COMPILER_IS_GNUCXX )
  if ( WITH_ATOMIC_OPS STREQUAL "up" )
    set ( MY_ATOMIC_MODE_DUMMY 1 CACHE BOOL "Assume single-CPU mode, no concurrency" )
  elseif ( WITH_ATOMIC_OPS STREQUAL "rwlocks" )
  set ( MY_ATOMIC_MODE_RWLOCK 1 CACHE BOOL "Use pthread rwlocks for atomic ops" )
  elseif ( WITH_ATOMIC_OPS STREQUAL "smp" )
  elseif ( NOT WITH_ATOMIC_OPS )
  check_cxx_source_compiles ( " int main() { int foo= -10; int bar= 10; long long int foo64= -10; long long int bar64= 10; if (!__sync_fetch_and_add(&amp;foo, bar) || foo) return -1; bar= __sync_lock_test_and_set(&amp;foo, bar); if (bar || foo != 10) return -1; bar= __sync_val_compare_and_swap(&amp;bar, foo, 15); if (bar) return -1; if (!__sync_fetch_and_add(&amp;foo64, bar64) || foo64) return -1; bar64= __sync_lock_test_and_set(&amp;foo64, bar64); if (bar64 || foo64 != 10) return -1; bar64= __sync_val_compare_and_swap(&amp;bar64, foo, 15); if (bar64) return -1; return 0; }" 
    HAVE_GCC_ATOMIC_BUILTINS )
  else ( )
    message ( FATAL_ERROR "${WITH_ATOMIC_OPS} is not a valid value for WITH_ATOMIC_OPS!" )
  endif ( )
endif ( )

set ( WITH_ATOMIC_LOCKS "${WITH_ATOMIC_LOCKS}" CACHE STRING "Implement atomic operations using pthread rwlocks or atomic CPU instructions for multi-processor or uniprocessor configuration. By default gcc built-in sync functions are used, if available and 'smp' configuration otherwise." )
mark_as_advanced ( WITH_ATOMIC_LOCKS MY_ATOMIC_MODE_RWLOCK MY_ATOMIC_MODE_DUMMY )

if ( WITH_VALGRIND )
  check_include_files ( "valgrind/memcheck.h;valgrind/valgrind.h" HAVE_VALGRIND_HEADERS )
  if ( HAVE_VALGRIND_HEADERS )
    set ( HAVE_VALGRIND 1 )
  endif ( )
endif ( )

#--------------------------------------------------------------------
# Check for IPv6 support
#--------------------------------------------------------------------
check_include_file ( netinet/in6.h HAVE_NETINET_IN6_H )

if ( UNIX )
  set ( CMAKE_EXTRA_INCLUDE_FILES sys/types.h netinet/in.h sys/socket.h netdb.h )
  if ( HAVE_NETINET_IN6_H )
    set ( CMAKE_EXTRA_INCLUDE_FILES ${CMAKE_EXTRA_INCLUDE_FILES} netinet/in6.h )
  endif ( )
elseif ( WIN32 )
set ( CMAKE_EXTRA_INCLUDE_FILES ${CMAKE_EXTRA_INCLUDE_FILES} winsock2.h ws2ipdef.h )
endif ( )

my_check_struct_size ( "sockaddr_in6" SOCKADDR_IN6 )
my_check_struct_size ( "in6_addr" IN6_ADDR )
my_check_struct_size ( "addrinfo" ADDRINFO )
my_check_struct_size ( "sockaddr_storage" SOCKADDR_STORAGE )

if ( HAVE_STRUCT_SOCKADDR_IN6 OR HAVE_STRUCT_IN6_ADDR )
  set ( HAVE_IPV6 TRUE CACHE INTERNAL "" )
endif ( )

# Check for sockaddr_storage.ss_family
# It is called differently under OS400 and older AIX
check_struct_has_member ( "struct sockaddr_storage" ss_family "${CMAKE_EXTRA_INCLUDE_FILES}" 
  HAVE_SOCKADDR_STORAGE_SS_FAMILY )
if ( NOT HAVE_SOCKADDR_STORAGE_SS_FAMILY )
  check_struct_has_member ( "struct sockaddr_storage" __ss_family "${CMAKE_EXTRA_INCLUDE_FILES}" 
    HAVE_SOCKADDR_STORAGE___SS_FAMILY )
  if ( HAVE_SOCKADDR_STORAGE___SS_FAMILY )
    set ( ss_family __ss_family )
  endif ( )
endif ( )
set ( HAVE_STRUCT_SOCKADDR_STORAGE_SS_FAMILY ${HAVE_SOCKADDR_STORAGE_SS_FAMILY} )
set ( HAVE_STRUCT_SOCKADDR_STORAGE___SS_FAMILY ${HAVE_SOCKADDR_STORAGE___SS_FAMILY} )
#
# Check if struct sockaddr_in::sin_len is available.
#

check_struct_has_member ( "struct sockaddr_in" sin_len "${CMAKE_EXTRA_INCLUDE_FILES}" 
  HAVE_SOCKADDR_IN_SIN_LEN )

#
# Check if struct sockaddr_in6::sin6_len is available.
#

check_struct_has_member ( "struct sockaddr_in6" sin6_len "${CMAKE_EXTRA_INCLUDE_FILES}" 
  HAVE_SOCKADDR_IN6_SIN6_LEN )

set ( CMAKE_EXTRA_INCLUDE_FILES )

check_struct_has_member ( "struct dirent" d_ino "dirent.h" STRUCT_DIRENT_HAS_D_INO )
check_struct_has_member ( "struct dirent" d_namlen "dirent.h" STRUCT_DIRENT_HAS_D_NAMLEN )
set ( SPRINTF_RETURNS_INT 1 )
