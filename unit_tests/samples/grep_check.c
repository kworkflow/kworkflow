// SPDX-License-Identifier: GPL-2.0
/*
 * grep_check.c
 *
 * Copyright (C) 2018 John Doe
 *
 * This file is used for GNU grep checking.
 *
 */

#include <stdio.h>

void camelCase(void)
{
	puts("One should avoid camel case.");
}

int main(int argc, char *args[])
{
	int i;

	printf("%d\n", argc);
	for (i = 0; i < argc; ++i)
		printf("%s ", args[i]);
	return 0;
}
