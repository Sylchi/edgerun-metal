#![no_std]

use core::{
    alloc::{GlobalAlloc, Layout},
    panic::PanicInfo,
    ptr, slice,
    sync::atomic::{AtomicUsize, Ordering},
};

use edgerun_crypto::{
    curve25519_dalek::{
        edwards::{CompressedEdwardsY, EdwardsPoint},
        scalar::Scalar,
    },
    digest::Digest,
    sha2::Sha512,
    signing, verification, Ed25519SigningKey,
};

const ERR_NULL: i32 = -1;
const ERR_VERIFY: i32 = -2;
const ERR_INVALID: i32 = -3;
const HEAP_SIZE: usize = 64 * 1024;
const RH_BLIND_STRING: &[u8] = b"Derive temporary signing key hash input";

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

#[no_mangle]
pub extern "C" fn edgerun_signing_blind_public_key(
    public_key_ptr: *const u8,
    blinding_factor_ptr: *const u8,
    out_ptr: *mut u8,
) -> i32 {
    if public_key_ptr.is_null() || blinding_factor_ptr.is_null() || out_ptr.is_null() {
        return ERR_NULL;
    }

    let public_key = unsafe { &*(public_key_ptr as *const [u8; 32]) };
    let mut blinding_factor = unsafe { *(blinding_factor_ptr as *const [u8; 32]) };
    blinding_factor[0] &= 248;
    blinding_factor[31] &= 63;
    blinding_factor[31] |= 64;

    let Some(point) = CompressedEdwardsY(*public_key).decompress() else {
        return ERR_INVALID;
    };
    let scalar = Scalar::from_bytes_mod_order(blinding_factor);
    let blinded = (&point * &scalar).compress().to_bytes();
    unsafe { ptr::copy_nonoverlapping(blinded.as_ptr(), out_ptr, 32) };
    0
}

#[no_mangle]
pub extern "C" fn edgerun_signing_blind_sign(
    seed_ptr: *const u8,
    blinding_factor_ptr: *const u8,
    msg_ptr: *const u8,
    msg_len: usize,
    out_sig_ptr: *mut u8,
    out_public_key_ptr: *mut u8,
) -> i32 {
    if seed_ptr.is_null()
        || blinding_factor_ptr.is_null()
        || out_sig_ptr.is_null()
        || (msg_ptr.is_null() && msg_len != 0)
    {
        return ERR_NULL;
    }

    let seed = unsafe { &*(seed_ptr as *const [u8; 32]) };
    let message = unsafe { slice::from_raw_parts(msg_ptr, msg_len) };
    let mut seed_digest = Sha512::new();
    seed_digest.update(seed);
    let seed_hash = seed_digest.finalize();

    let mut scalar_bytes = [0u8; 32];
    scalar_bytes.copy_from_slice(&seed_hash[..32]);
    scalar_bytes[0] &= 248;
    scalar_bytes[31] &= 63;
    scalar_bytes[31] |= 64;
    let identity_scalar = Scalar::from_bytes_mod_order(scalar_bytes);

    let mut blinding_factor = unsafe { *(blinding_factor_ptr as *const [u8; 32]) };
    blinding_factor[0] &= 248;
    blinding_factor[31] &= 63;
    blinding_factor[31] |= 64;
    let blind_scalar = Scalar::from_bytes_mod_order(blinding_factor);
    let blinded_scalar = blind_scalar * identity_scalar;
    let blinded_public_key = EdwardsPoint::mul_base(&blinded_scalar).compress().to_bytes();

    let mut rh_digest = Sha512::new();
    rh_digest.update(RH_BLIND_STRING);
    rh_digest.update(&seed_hash[32..64]);
    let rh_hash = rh_digest.finalize();

    let mut nonce_digest = Sha512::new();
    nonce_digest.update(&rh_hash[..32]);
    nonce_digest.update(message);
    let nonce = Scalar::from_hash(nonce_digest);
    let r_bytes = EdwardsPoint::mul_base(&nonce).compress().to_bytes();

    let mut challenge_digest = Sha512::new();
    challenge_digest.update(r_bytes);
    challenge_digest.update(blinded_public_key);
    challenge_digest.update(message);
    let challenge = Scalar::from_hash(challenge_digest);
    let s = (challenge * blinded_scalar) + nonce;
    let s_bytes = s.to_bytes();

    unsafe {
        ptr::copy_nonoverlapping(r_bytes.as_ptr(), out_sig_ptr, 32);
        ptr::copy_nonoverlapping(s_bytes.as_ptr(), out_sig_ptr.add(32), 32);
        if !out_public_key_ptr.is_null() {
            ptr::copy_nonoverlapping(blinded_public_key.as_ptr(), out_public_key_ptr, 32);
        }
    }
    0
}
