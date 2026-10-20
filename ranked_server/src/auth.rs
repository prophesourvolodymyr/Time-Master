use crate::{ApiError, Result};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use scrypt::{Params, scrypt};
use sha2::{Digest, Sha256};
use std::sync::Arc;
use subtle::ConstantTimeEq;
use tokio::sync::Semaphore;

pub(crate) fn digest(value: impl AsRef<[u8]>) -> String {
    hex::encode(Sha256::digest(value.as_ref()))
}

pub(crate) fn token<const N: usize>() -> Result<String> {
    let mut bytes = [0; N];
    getrandom::fill(&mut bytes).map_err(|_| ApiError::internal())?;
    Ok(URL_SAFE_NO_PAD.encode(bytes))
}

pub(crate) fn identifier() -> Result<String> {
    let mut bytes = [0; 16];
    getrandom::fill(&mut bytes).map_err(|_| ApiError::internal())?;
    Ok(hex::encode(bytes))
}

fn password_hash(password: &str, salt: Option<[u8; 16]>) -> Result<String> {
    let salt = match salt {
        Some(salt) => salt,
        None => {
            let mut salt = [0; 16];
            getrandom::fill(&mut salt).map_err(|_| ApiError::internal())?;
            salt
        }
    };
    let params = Params::new(15, 8, 1, 64).map_err(|_| ApiError::internal())?;
    let mut key = [0; 64];
    scrypt(password.as_bytes(), &salt, &params, &mut key).map_err(|_| ApiError::internal())?;
    let mut output = vec![b':'; 161];
    hex::encode_to_slice(salt, &mut output[..32]).map_err(|_| ApiError::internal())?;
    hex::encode_to_slice(key, &mut output[33..]).map_err(|_| ApiError::internal())?;
    String::from_utf8(output).map_err(|_| ApiError::internal())
}

#[derive(Clone)]
pub(crate) struct PasswordWork {
    permits: Arc<Semaphore>,
    dummy: Arc<str>,
}

impl PasswordWork {
    pub async fn new() -> Result<Self> {
        let password = token::<24>()?;
        let dummy = tokio::task::spawn_blocking(move || password_hash(&password, None))
            .await
            .map_err(|_| ApiError::internal())??;
        Ok(Self {
            permits: Arc::new(Semaphore::new(2)),
            dummy: dummy.into(),
        })
    }

    pub async fn hash(&self, password: String) -> Result<String> {
        let permit = self
            .permits
            .clone()
            .acquire_owned()
            .await
            .map_err(|_| ApiError::internal())?;
        tokio::task::spawn_blocking(move || {
            let _permit = permit;
            password_hash(&password, None)
        })
        .await
        .map_err(|_| ApiError::internal())?
    }

    pub async fn verify(&self, password: String, stored: Option<String>) -> Result<bool> {
        let permit = self
            .permits
            .clone()
            .acquire_owned()
            .await
            .map_err(|_| ApiError::internal())?;
        let dummy = self.dummy.clone();
        tokio::task::spawn_blocking(move || {
            let _permit = permit;
            let candidate = stored.as_deref().unwrap_or(&dummy);
            let mut salt = [0; 16];
            let valid_format = candidate.len() == 161
                && candidate.as_bytes()[32] == b':'
                && hex::decode_to_slice(&candidate.as_bytes()[..32], &mut salt).is_ok();
            if !valid_format {
                hex::decode_to_slice(&dummy.as_bytes()[..32], &mut salt)
                    .map_err(|_| ApiError::internal())?;
            }
            let computed = password_hash(&password, Some(salt))?;
            Ok(bool::from(computed.as_bytes().ct_eq(candidate.as_bytes()))
                && stored.is_some()
                && valid_format)
        })
        .await
        .map_err(|_| ApiError::internal())?
    }
}
