# src/bin/initdb/nls.mk
CATALOG_NAME	:= initdb
AVAIL_LANGUAGES	:= cs de es fr it ja ko pl pt_BR ro ru sv tr zh_CN zh_TW
GETTEXT_FILES	:= initdb.c ../../port/dirmod.c ../../port/exec.c
GETTEXT_TRIGGERS:= _ simple_prompt
