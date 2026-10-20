use crate::{
    ApiError, Result,
    rules::{Pose, Variation},
};
use serde::{Deserialize, Serialize};

pub(crate) trait Validate {
    fn validate(&mut self) -> Result<()>;
}

fn length(value: &str, minimum: usize, maximum: usize) -> bool {
    let count = value.chars().count();
    (minimum..=maximum).contains(&count)
}

fn credentials(login: &mut String, password: &str) -> Result<()> {
    if !length(login, 3, 64) || !length(password, 12, 128) {
        return Err(ApiError::invalid("Invalid login or password length"));
    }
    *login = login.trim().to_ascii_lowercase();
    if !(3..=64).contains(&login.len())
        || !login
            .bytes()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || b"_.@+-".contains(&c))
    {
        return Err(ApiError::invalid(
            "Use a private login of 3–64 letters, numbers or . _ @ + -",
        ));
    }
    Ok(())
}

fn display_name(value: &str) -> Result<()> {
    if !length(value, 1, 60) {
        return Err(ApiError::invalid(
            "Public name must contain 1–60 characters",
        ));
    }
    Ok(())
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Credentials {
    pub login: String,
    pub password: String,
}

impl Validate for Credentials {
    fn validate(&mut self) -> Result<()> {
        credentials(&mut self.login, &self.password)
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Registration {
    pub login: String,
    pub password: String,
    pub display_name: String,
    #[serde(default)]
    pub listed: bool,
}

impl Validate for Registration {
    fn validate(&mut self) -> Result<()> {
        credentials(&mut self.login, &self.password)?;
        display_name(&self.display_name)
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Refresh {
    pub refresh_token: String,
}

impl Validate for Refresh {
    fn validate(&mut self) -> Result<()> {
        if !length(&self.refresh_token, 32, 128) {
            return Err(ApiError::invalid("Invalid refresh token"));
        }
        Ok(())
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct QueueEntry {
    pub variation: String,
    pub rule_version: String,
    #[serde(rename = "requestID")]
    pub request_id: String,
}

impl Validate for QueueEntry {
    fn validate(&mut self) -> Result<()> {
        if !length(&self.request_id, 16, 80) {
            return Err(ApiError::invalid("Invalid request identity"));
        }
        Ok(())
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Ready {
    pub ready: bool,
    #[serde(default)]
    pub calibration: Vec<Pose>,
}

impl Validate for Ready {
    fn validate(&mut self) -> Result<()> {
        if self.calibration.len() > 30 {
            return Err(ApiError::invalid("Too many calibration frames"));
        }
        Ok(())
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Presence {
    pub active: bool,
    pub calibrated: bool,
}

impl Validate for Presence {
    fn validate(&mut self) -> Result<()> {
        Ok(())
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Evidence {
    pub nonce: String,
    pub rule_version: String,
    pub sequence: i64,
    pub frames: Vec<Pose>,
}

impl Validate for Evidence {
    fn validate(&mut self) -> Result<()> {
        if !length(&self.nonce, 32, 128)
            || !(0..=10000).contains(&self.sequence)
            || !(1..=30).contains(&self.frames.len())
        {
            return Err(ApiError::invalid("Invalid evidence batch"));
        }
        Ok(())
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Privacy {
    pub display_name: String,
    pub listed: bool,
}

impl Validate for Privacy {
    fn validate(&mut self) -> Result<()> {
        display_name(&self.display_name)
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Grant {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: f64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Identity {
    #[serde(rename = "publicID")]
    pub public_id: String,
    pub display_name: String,
    pub listed: bool,
}

#[derive(Serialize)]
pub(crate) struct Rating {
    pub variation: Variation,
    pub rating: i64,
    pub games: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Allowance {
    pub family: &'static str,
    pub remaining: Option<i64>,
    pub next_slot: Option<f64>,
}

#[derive(Serialize)]
pub(crate) struct Account {
    pub identity: Identity,
    pub ratings: Vec<Rating>,
    pub allowances: [Allowance; 3],
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Participant {
    #[serde(rename = "publicID")]
    pub public_id: String,
    pub display_name: String,
    pub is_you: bool,
    pub ready: bool,
    pub score: f64,
    pub last_seen: f64,
    pub verification: String,
    pub before_rating: Option<i64>,
    pub after_rating: Option<i64>,
    pub nonce: Option<String>,
    pub next_sequence: Option<i64>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Match {
    pub id: String,
    pub variation: Variation,
    pub rule_version: String,
    pub state: String,
    pub created_at: f64,
    pub ready_deadline: f64,
    pub start_at: Option<f64>,
    pub end_at: Option<f64>,
    pub reason: Option<String>,
    pub winner: Option<String>,
    pub revision: i64,
    pub participants: Vec<Participant>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Queued {
    pub variation: Variation,
    pub expires_at: f64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ServiceState {
    pub server_time: f64,
    pub queue: Option<Queued>,
    pub r#match: Option<Match>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MatchResponse {
    pub server_time: f64,
    pub r#match: Match,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Receipt {
    pub next_sequence: i64,
    pub score: f64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct History {
    pub matches: Vec<Match>,
    pub next_cursor: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Standing {
    #[serde(rename = "publicID")]
    pub public_id: String,
    pub display_name: String,
    pub rating: i64,
    pub games: i64,
    pub position: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Leaderboard {
    pub rows: Vec<Standing>,
    pub me: Option<Standing>,
    pub next_cursor: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct Player {
    #[serde(rename = "publicID")]
    pub public_id: String,
    pub display_name: String,
    pub ratings: Vec<Rating>,
}
