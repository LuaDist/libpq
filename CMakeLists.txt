# Copyright (C) 2007-2012 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

project ( libpq C )
cmake_minimum_required ( VERSION 2.8 )
include ( cmake/dist.cmake )

# Defines
add_definitions ( -D_REENTRANT -D_THREAD_SAFE -D_POSIX_PTHREAD_SEMANTICS -DFRONTEND -DUNSAFE_STAT_OK )

# Incudes
include_directories ( src/include src/port )

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

  # src/port
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

if ( UNIX AND NOT APPLE )
  add_definitions ( -D_GNU_SOURCE )
  list ( APPEND SRC
    src/interfaces/libpq/strlcpy.c
    src/interfaces/libpq/getpeereid.c
  )
  find_package ( Threads REQUIRED )
  list ( APPEND LIBS ${CMAKE_THREAD_LIBS_INIT} )
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
