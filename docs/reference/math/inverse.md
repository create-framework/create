# inverse

```mojo
def inverse[N: Int](m: Matrix[N, N]) -> Matrix[N, N]
```

The transform that undoes `m` — Gauss-Jordan with partial pivoting.

Mapping a point back out of a transformed frame is what this is for, which
is how `canvas.to_local` maps a mouse position into the current transform.
A singular matrix (a zero scale, say) has no inverse and the result is
meaningless rather than an error.
