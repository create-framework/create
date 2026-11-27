# DateTime

```mojo
struct DateTime
```

A calendar date and local time of day, read all at once.

`DateTime.now()` takes one reading, so its fields always agree with each
other: reading hour and minute from separate clock calls can straddle a
rollover and report 13:59 at 12:59:59.999. Unlike `context.time`, this is
the computer's clock, not the run's: it doesn't start at zero, and a
headless run sees the real date.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `year: Int`: The full year, such as 2026.
- `month: Int`: 1 (January) to 12 (December).
- `day: Int`: Day of the month, from 1.
- `hour: Int`: 0 to 23.
- `minute: Int`: 0 to 59.
- `second: Int`: 0 to 59, or 60 during a leap second.
- `millisecond: Int`: 0 to 999, for motion smoother than whole seconds.

## Constructors

### `now`

```mojo
@staticmethod
def now() -> Self
```

The current local date and time, in the system's time zone.
