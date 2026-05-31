#![no_std]

use core::{
    alloc::{GlobalAlloc, Layout},
    panic::PanicInfo,
    ptr, slice,
    sync::atomic::{AtomicUsize, Ordering},
};

use edgerun_crypto::{signing, verification, Ed25519SigningKey};

const ERR_NULL: i32 = -1;
const ERR_VERIFY: i32 = -2;
const HEAP_SIZE: usize = 64 * 1024;

struct BumpAllocator;

static HEAP_OFFSET: AtomicUsize = AtomicUsize::new(0);
static mut HEAP: [u8; HEAP_SIZE] = [0; HEAP_SIZE];

#[global_allocator]
static ALLOCATOR: BumpAllocator = BumpAllocator;

unsafe impl GlobalAlloc for BumpAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let align = layout.align().max(1);
        let size = layout.size();
        let mut current = HEAP_OFFSET.load(Ordering::Relaxed);

        loop {
            let aligned = (current + align - 1) & !(align - 1);
            let next = match aligned.checked_add(size) {
                Some(next) if next <= HEAP_SIZE => next,
                _ => return ptr::null_mut(),
            };

            match HEAP_OFFSET.compare_exchange(current, next, Ordering::SeqCst, Ordering::SeqCst) {
                Ok(_) => return ptr::addr_of_mut!(HEAP).cast::<u8>().add(aligned),
                Err(actual) => current = actual,
            }
        }
    }

    unsafe fn dealloc(&self, _: *mut u8, _: Layout) {}
}

#[panic_handler]
fn panic(_: &PanicInfo<'_>) -> ! {
    loop {}
}

#[no_mangle]
pub extern "C" fn edgerun_signing_public_key(seed_ptr: *const u8, out_ptr: *mut u8) -> i32 {
    if seed_ptr.is_null() || out_ptr.is_null() {
        return ERR_NULL;
    }

    let seed = unsafe { &*(seed_ptr as *const [u8; 32]) };
    let key = Ed25519SigningKey::from_bytes(seed);
    let public_key = signing::ed25519_public_key(&key);
    unsafe { ptr::copy_nonoverlapping(public_key.as_ptr(), out_ptr, 32) };
    0
}

#[no_mangle]
pub extern "C" fn edgerun_signing_sign(
    seed_ptr: *const u8,
    msg_ptr: *const u8,
    msg_len: usize,
    out_ptr: *mut u8,
) -> i32 {
    if seed_ptr.is_null() || out_ptr.is_null() || (msg_ptr.is_null() && msg_len != 0) {
        return ERR_NULL;
    }

    let seed = unsafe { &*(seed_ptr as *const [u8; 32]) };
    let message = unsafe { slice::from_raw_parts(msg_ptr, msg_len) };
    let key = Ed25519SigningKey::from_bytes(seed);
    let signature = signing::ed25519_sign(&key, message);
    unsafe { ptr::copy_nonoverlapping(signature.as_ptr(), out_ptr, 64) };
    0
}

#[no_mangle]
pub extern "C" fn edgerun_signing_verify(
    public_key_ptr: *const u8,
    msg_ptr: *const u8,
    msg_len: usize,
    signature_ptr: *const u8,
) -> i32 {
    if public_key_ptr.is_null()
        || signature_ptr.is_null()
        || (msg_ptr.is_null() && msg_len != 0)
    {
        return ERR_NULL;
    }

    let public_key = unsafe { slice::from_raw_parts(public_key_ptr, 32) };
    let message = unsafe { slice::from_raw_parts(msg_ptr, msg_len) };
    let signature = unsafe { slice::from_raw_parts(signature_ptr, 64) };
    match verification::ed25519_verify(public_key, message, signature) {
        Ok(()) => 0,
        Err(_) => ERR_VERIFY,
    }
}
