#include <stdio.h>
#include "ada_greet.h"

int main(void) {
    int result = ada_compute(5);
    printf("ada_compute(5) = %d\n", result);
    return result == 17 ? 0 : 1;
}
