/[A-Z]*=/ {
    split($0, a, "=");
    v = a[1];
    printf("s:%%%s%%:${%s}:g\n", v, v);
}
