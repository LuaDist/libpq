# Copyright (C) 2007-2012 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

project ( libpq C )
cmake_minimum_required ( VERSION 2.8 )
include ( cmake/dist.cmake )

# Defines
add_definitions ( -D_REENTRANT -D_THREAD_SAFE -D_POSIX_PTHREAD_SEMANTICS  -DFRONTEND -DUNSAFE_STAT_OK )

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
  src/interfaces/libpq/pqexpbuffer.c 
  src/interfaces/libpq/pqsignal.c 
  src/interfaces/libpq/fe-secure.c 
  src/interfaces/libpq/libpq-events.c 
  src/interfaces/libpq/fe-protocol3.c 
  src/port/chklocale.c
  src/port/inet_net_ntop.c
  src/port/noblock.c
  src/port/pgstrcasecmp.c
  src/port/thread.c
  src/backend/libpq/ip.c
  src/backend/libpq/md5.c
  src/backend/utils/mb/encnames.c
  src/backend/utils/mb/wchar.c
)

# Build libpq
add_library ( pq ${SRC} )
target_link_libraries ( pq ${LIBS} )

# Install the lib and headers
install_library ( pq )
install_header ( src/interfaces/libpq/libpq-fe.h src/interfaces/libpq/libpq-events.h 
  src/interfaces/libpq/libpq-int.h src/interfaces/libpq/pqexpbuffer.h src/include/postgres_ext.h 
  src/include/pg_config_manual.h )
install_header ( src/include/libpq/libpq-fs.h INTO libpq )
