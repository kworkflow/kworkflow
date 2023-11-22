// SPDX-License-Identifier: GPL-2.0
/*
 * codestyle.c
 *
 * Copyright (C) 2018 Bob Hilson
 *
 * This file is used to test the print_files_authors function
 * at src/maintainers.sh.
 *
 */

#include <stdio.h>

void ordinary_function2(void)
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

MODULE_AUTHOR ( "Bob Hilson <bob@opensource.com>" )
