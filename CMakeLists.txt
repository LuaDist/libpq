# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

# 2DO: Crypto support
# For now this build contains the bare minimum to get PostgreSQL running

project ( libpq C CXX ) # CXX Required for configure
cmake_minimum_required ( VERSION 2.8.5 )
include ( dist.cmake )
include ( configure.cmake )

# Configuration
set(PG_VERSION_NUM 90101)
set(ACCEPT_TYPE_ARG1 "unsigned int")
set(ACCEPT_TYPE_ARG2 "struct sockaddr")
set(ACCEPT_TYPE_ARG3 "int")
set(DEF_PGPORT 5432)
set(DEF_PGPORT_STR "${DEF_PGPORT}")
set(MEMSET_LOOP_LIMIT 512)
set(MAXIMUM_ALIGNOF 8)

# libpq sources
set ( SRC 
  	src/interfaces/libpq/fe-auth.c
  	src/interfaces/libpq/fe-protocol2.c
  	src/interfaces/libpq/fe-protocol3.c
  	src/interfaces/libpq/fe-connect.c
  	src/interfaces/libpq/fe-exec.c
  	src/interfaces/libpq/fe-lobj.c
  	src/interfaces/libpq/fe-misc.c
  	src/interfaces/libpq/fe-print.c
  	src/interfaces/libpq/fe-secure.c
  	src/interfaces/libpq/libpq-events.c
  	src/interfaces/libpq/pqexpbuffer.c
  	src/interfaces/libpq/pqsignal.c
  	src/backend/libpq/md5.c
  	src/backend/libpq/ip.c
  	src/backend/utils/mb/encnames.c
  	src/backend/utils/mb/wchar.c
  	src/port/pgstrcasecmp.c
  	src/port/thread.c
  	src/port/inet_aton.c
  	src/port/noblock.c
  	src/port/chklocale.c
  	src/port/inet_net_ntop.c
  	src/port/getaddrinfo.c
  	src/port/snprintf.c
  	src/port/strlcpy.c
  	src/port/dirmod.c
  	src/port/open.c
#  	src/port/crypt.c
#  	src/port/dirent.c
)

# Quick fix for the <net/if.h> check that fails on OSX
if (APPLE)
  set(HAVE_NET_IF_H 1)
elseif (CYGWIN)
  set(SRC ${SRC} src/port/pgsleep.c)
  configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/cygwin.h ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config_os.h )
elseif (WIN32)
  #Minor configuration corrections
  set(HAVE_STRUCT_ADDRINFO 1)
  set(HAVE_STRUCT_SOCKADDR_STORAGE 1)
  set(HAVE_STRUCT_SOCKADDR_STORAGE_SS_FAMILY 1)
  set(KRB5 0)
  set(ENABLE_GSS 0)
  set(ENABLE_SSPI 0)

  add_definitions ( -DEXEC_BACKEND )
  include_directories ( 
	${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/ 
	${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/win32   
  )
  #Additional libs needed on win32
  set(LIBS -lkernel32 -luser32 -ladvapi32 -lshfolder -lwsock32 -lws2_32 -lsecur32)
  set(SRC ${SRC}
      	src/interfaces/libpq/win32.c
      	src/interfaces/libpq/pthread-win32.c
      	src/port/win32error.c
      	src/port/win32setlocale.c
      	src/port/pgsleep.c
  )
  
  configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/win32.h ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config_os.h )
else() 
  configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/port/linux.h ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config_os.h )
endif()

# Generate configured headers
configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config.h.in ${CMAKE_CURRENT_SOURCE_DIR}/src/include/pg_config.h )
configure_file ( ${CMAKE_CURRENT_SOURCE_DIR}/src/port/pg_config_paths.h.in ${CMAKE_CURRENT_SOURCE_DIR}/src/port/pg_config_paths.h )

# Setup include directories and defines
include_directories ( src/include src/port )
add_definitions ( -DFRONTEND -DUNSAFE_STAT_OK )

# Build libpq
add_library ( pq SHARED ${SRC})
target_link_libraries ( pq ${LIBS} )
# Install the lib and headers
install_library ( pq )
install_header ( 
  src/interfaces/libpq/libpq-fe.h
  src/interfaces/libpq/libpq-events.h
  src/interfaces/libpq/libpq-int.h
  src/interfaces/libpq/pqexpbuffer.h
  src/include/postgres_ext.h
  src/include/pg_config_manual.h
)
install_header (
  src/include/libpq/libpq-fs.h
  INTO libpq
)
