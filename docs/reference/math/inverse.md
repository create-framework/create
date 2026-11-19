# inverse

```mojo
def inverse[N: Int](m: Matrix[N, N]) -> Matrix[N, N]
```

The matrix that undoes `m`: `inverse(m) @ m` is the identity.

Found by Gauss-Jordan elimination with partial pivoting. A singular
matrix, one that squashes some direction to nothing, has no inverse, and
the result holds meaningless numbers rather than raising an error.
