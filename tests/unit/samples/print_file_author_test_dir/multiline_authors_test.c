// SPDX-License-Identifier: GPL-2.0
/*
 * codestyle.c
 *
 * Copyright (C) 2024 Martha Elsa
 *
 * This file is used to test the print_files_authors function
 * at src/maintainers.sh.
 *
 */

#include <stdio.h>

void ordinary_dummy_function(void)
{
	puts("Just a function...");
}

int main(int argc, char *args[])
{
	int i;
	printf("%d\n", argc);
	for (i = 0; i < argc; ++i)
		printf("%s ", args[i]);
	return 0;
}

MODULE_AUTHOR ( "Martha Elsa <martha@opensource.com>" \
				"Verena Bert <vb@opensource.com>" )
ORDINARY_MACRO ( "Does something..." )
MODULE_AUTHOR ( "Gabi Katinka <gabik@opensource.com>\n"
				"Leonie Hildebert <leoni.hildebert@opensource.com>" )