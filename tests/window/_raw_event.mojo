"""Test-only helpers for building raw SDL_Event byte buffers, and for
reading a window's events past the dummy driver's focus churn.

Field offsets are imported from `create._window._sdl` rather than duplicated here,
so these helpers stay pinned to the same ABI layout `Window.events()` reads.
"""

from create._window import Event, FocusLost, NativeWindow
from create._window._sdl import SDL_EVENT_SIZE


def new_event_buffer(kind: UInt32) -> Array[UInt8, SDL_EVENT_SIZE]:
    var buf = Array[UInt8, SDL_EVENT_SIZE](fill=0)
    buf.unsafe_ptr().unsafe_bitcast[UInt32]()[] = kind
    return buf^


def write_u8(mut buf: Array[UInt8, SDL_EVENT_SIZE], offset: Int, value: UInt8):
    buf.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[UInt8]()[] = value


def write_i16(mut buf: Array[UInt8, SDL_EVENT_SIZE], offset: Int, value: Int16):
    buf.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[Int16]()[] = value


def write_u32(
    mut buf: Array[UInt8, SDL_EVENT_SIZE], offset: Int, value: UInt32
):
    buf.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[UInt32]()[] = value


def write_i32(mut buf: Array[UInt8, SDL_EVENT_SIZE], offset: Int, value: Int32):
    buf.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[Int32]()[] = value


def write_f32(
    mut buf: Array[UInt8, SDL_EVENT_SIZE], offset: Int, value: Float32
):
    buf.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[Float32]()[] = value


def write_pointer(
    mut buf: Array[UInt8, SDL_EVENT_SIZE],
    offset: Int,
    value: Pointer[Int8, _],
):
    buf.unsafe_ptr().unsafe_offset(offset).unsafe_bitcast[
        type_of(value)
    ]()[] = value


def events_without_focus[W: NativeWindow](mut window: W) raises -> List[Event]:
    """`window.events()` without its focus changes. SDL's dummy driver hides,
    shows and refocuses every window a process opens on its own, so a test
    counting the events it pushed has to look past those."""
    var events = List[Event]()
    for event in window.events():
        if not event.isa[FocusLost]():
            events.append(event)
    return events^
