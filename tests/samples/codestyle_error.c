// SPDX-License-Identifier: GPL-2.0
/*
 * codestyle.c
 *
 * Copyright (C) 2018 John Doe
 *
 * This file is used for codestyle checking.
 *
 */

#include <stdio.h>

int main(int argc, char *args[]) {
	int i;

	printf("%d\n", argc);
	for (i = 0; i < argc; ++i)
		printf("%s ", args[i]);
	return 0;
}
