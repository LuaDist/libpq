# Copyright (C) 2007-2012 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

project ( libpq C CXX)
cmake_minimum_required ( VERSION 2.8 )
include ( cmake/dist.cmake )

# Includes
include_directories ( ${CMAKE_CURRENT_BINARY_DIR} src/include  )

# Configuration
configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/port/pg_config_paths.h.in ${CMAKE_CURRENT_SOURCE_DIR}/src/port/pg_config_paths.h )

#set ( PG_VERSION_NUM 90201 )
#set ( ACCEPT_TYPE_ARG1 "unsigned int" )
#set ( ACCEPT_TYPE_ARG2 "struct sockaddr" )
#set ( ACCEPT_TYPE_ARG3 "int" )
#set ( DEF_PGPORT 5432 )
#set ( DEF_PGPORT_STR "${DEF_PGPORT}" )
#set ( MEMSET_LOOP_LIMIT 512 )
#set ( MAXIMUM_ALIGNOF 8 )

# libpq sources
set ( SRC 
  src/interfaces/libpq/fe-auth.c 
  src/interfaces/libpq/fe-connect.c 
  src/interfaces/libpq/fe-exec.c 
  src/interfaces/libpq/fe-misc.c 
  src/interfaces/libpq/fe-print.c 
  src/interfaces/libpq/fe-lobj.c 
  src/interfaces/libpq/fe-protocol2.c 
  src/interfaces/libpq/fe-protocol3.c 
  src/interfaces/libpq/pqexpbuffer.c 
  src/interfaces/libpq/pqsignal.c 
  src/interfaces/libpq/fe-secure.c 
  src/interfaces/libpq/libpq-events.c 
)

if ( WIN32 )
  # Use provided header
  configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config.h.mingw ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config.h )

  add_definitions ( -DFRONTEND -DUNSAFE_STAT_OK -DSO_MAJOR_VERSION=5 -DEXEC_BACKEND -DBUILDING_DLL )
  include_directories ( src/include/port src/include/port/win32 src/port )
  # OS specific config
  configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/win32.h ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config_os.h )
  # On windows use port sources
  list ( APPEND SRC
    src/port/chklocale.c
    src/port/inet_net_ntop.c
    src/port/noblock.c
    src/port/pgstrcasecmp.c
    src/port/thread.c
    src/port/crypt.c
    src/port/inet_aton.c
    src/port/strlcpy.c
    src/port/getaddrinfo.c
    src/port/open.c
    src/port/win32error.c
    src/port/win32setlocale.c
    src/port/snprintf.c
    src/backend/libpq/ip.c
    src/backend/libpq/md5.c
    src/backend/utils/mb/encnames.c
    src/backend/utils/mb/wchar.c
    src/port/pgsleep.c
    src/interfaces/libpq/pthread-win32.c
    src/interfaces/libpq/win32.c
   )
  list ( APPEND LIBS -lshfolder -lwsock32 -lws2_32 -lsecur32 )
endif ()

if ( UNIX  )  
  # Generate configured header
  include ( configure )
  configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config.h )

  add_definitions ( -D_REENTRANT -D_THREAD_SAFE -D_POSIX_PTHREAD_SEMANTICS -DFRONTEND -DUNSAFE_STAT_OK )

  # For UNIX systems do not use port sources
  list ( APPEND SRC
    src/interfaces/libpq/chklocale.c
    src/interfaces/libpq/inet_net_ntop.c
    src/interfaces/libpq/noblock.c
    src/interfaces/libpq/pgstrcasecmp.c
    src/interfaces/libpq/thread.c

    src/interfaces/libpq/ip.c
    src/interfaces/libpq/md5.c
    src/interfaces/libpq/encnames.c
    src/interfaces/libpq/wchar.c
  )

  if ( NOT APPLE )
    # Assuming linux
    include_directories ( src/include/port src/port )
    configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/linux.h ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config_os.h )

    add_definitions ( -D_GNU_SOURCE )
    find_package ( Threads REQUIRED )
    list ( APPEND LIBS ${CMAKE_THREAD_LIBS_INIT} )
    list ( APPEND SRC
      src/interfaces/libpq/strlcpy.c
      src/interfaces/libpq/getpeereid.c
    )
  endif ()
endif ()

# Build libpq
add_library ( pq ${SRC} )
target_link_libraries ( pq ${LIBS} )

# Install the lib and headers
install_library ( pq )
install_header ( src/interfaces/libpq/libpq-fe.h src/interfaces/libpq/libpq-events.h 
  src/interfaces/libpq/libpq-int.h src/interfaces/libpq/pqexpbuffer.h src/include/postgres_ext.h 
  src/include/pg_config_manual.h )
install_header ( src/include/libpq/libpq-fs.h INTO libpq )
