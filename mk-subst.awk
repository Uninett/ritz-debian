/[A-Z]*=/ {
    split($0, a, "=");
    var = a[1];
    val = a[2];
    b = index(val, "${");
    if (b != 0) {
	e = index(val, "}");
	n = substr(val, b+2, e-b-2);
	h = substr(val, 1, b-1);
	r = substr(val, e+1);
	val = sprintf("%s%s%s", h, value[n], r);
    }
    printf("s:%%%s%%:%s:g\n", var, val);
    value[var] = val;
}
