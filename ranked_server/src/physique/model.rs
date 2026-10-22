use crate::{ApiError, Result};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Consent {
    pub adult: bool,
    pub adult_man: bool,
    pub rules_accepted: bool,
    pub ai_processing: bool,
    pub opponent_sharing: bool,
    pub policy_version: String,
}
impl Consent {
    pub fn accepted(&self, version: &str) -> bool {
        self.adult
            && self.rules_accepted
            && self.ai_processing
            && self.opponent_sharing
            && self.policy_version == version
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Policy {
    pub version: String,
    pub operator_name: String,
    pub processor: String,
    pub region: String,
    pub retention: String,
    pub judge_version: String,
    #[serde(rename = "supportURL")]
    pub support_url: Option<String>,
    pub ready: bool,
    pub unavailable_reason: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Badge {
    pub id: String,
    pub title: String,
    pub symbol: String,
    pub detail: String,
    pub earned_at: Option<f64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Identity {
    pub id: String,
    pub display_name: String,
    pub country_code: Option<String>,
    pub rating: Option<i64>,
    pub games: i64,
    pub tier: Option<String>,
    pub badges: Vec<Badge>,
    pub streak: Option<i64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Record {
    pub rating: Option<i64>,
    pub best: Option<i64>,
    pub games: i64,
    pub wins: i64,
    pub losses: i64,
    pub draws: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Allowance {
    pub remaining: i64,
    pub limit: i64,
    pub next_available_at: Option<f64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Account {
    pub identity: Identity,
    pub consent: Consent,
    pub consent_revision: Option<f64>,
    pub record: Record,
    pub allowance: Allowance,
    pub listed: bool,
    pub restricted_reason: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Participant {
    pub identity: Identity,
    pub ready: bool,
    pub submitted: bool,
    pub accepted_count: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Evidence {
    pub id: String,
    pub pose: String,
    pub status: String,
    pub retakes: i64,
    pub reason: Option<String>,
    #[serde(rename = "appealCaseID")]
    pub appeal_case_id: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Scores {
    pub muscularity: i64,
    pub definition: i64,
    pub symmetry: i64,
    pub presentation: i64,
    pub total: f64,
}
impl Scores {
    pub fn validate(&self) -> Result<()> {
        if [
            self.muscularity,
            self.definition,
            self.symmetry,
            self.presentation,
        ]
        .into_iter()
        .any(|v| !(0..=100).contains(&v))
        {
            return Err(ApiError::invalid("Judge category points are invalid"));
        }
        let tenths =
            self.muscularity * 4 + self.definition * 3 + self.symmetry * 2 + self.presentation;
        if !self.total.is_finite() || (self.total * 10.0 - tenths as f64).abs() > 0.000001 {
            return Err(ApiError::invalid(
                "Judge total does not match the fixed rubric",
            ));
        }
        Ok(())
    }
    pub fn tenths(&self) -> i64 {
        self.muscularity * 4 + self.definition * 3 + self.symmetry * 2 + self.presentation
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RatingReceipt {
    pub before: Option<i64>,
    pub change: i64,
    pub after: i64,
    pub games: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Correction {
    pub id: String,
    pub created_at: f64,
    pub reason: String,
    pub original_outcome: String,
    pub corrected_outcome: String,
    pub original_change: i64,
    pub adjustment: i64,
    pub after: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MatchResult {
    pub outcome: String,
    pub you: Option<Scores>,
    pub opponent: Option<Scores>,
    pub rating: Option<RatingReceipt>,
    pub explanation: Option<String>,
    pub judge_version: Option<String>,
    pub corrected: bool,
    pub correction: Option<Correction>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Match {
    pub id: String,
    pub stage: String,
    pub created_at: f64,
    pub start_at: Option<f64>,
    pub deadline: Option<f64>,
    pub judging_started_at: Option<f64>,
    pub judging_deadline: Option<f64>,
    pub finalized_at: Option<f64>,
    pub reason: Option<String>,
    pub you: Participant,
    pub opponent: Participant,
    pub evidence: Vec<Evidence>,
    pub result: Option<MatchResult>,
    pub gallery_available: bool,
    pub media_expires_at: Option<f64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub server_time: f64,
    pub policy: Policy,
    pub account: Account,
    pub r#match: Option<Match>,
    pub queue_started_at: Option<f64>,
    pub queue_deadline: Option<f64>,
    pub queue_outcome: Option<String>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CommandResponse {
    pub snapshot: Snapshot,
    #[serde(rename = "receiptID")]
    pub receipt_id: Option<String>,
    pub message: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Command {
    pub operation: String,
    #[serde(rename = "requestID")]
    pub request_id: String,
    #[serde(default, rename = "matchID")]
    pub match_id: Option<String>,
    #[serde(default, rename = "targetID")]
    pub target_id: Option<String>,
    #[serde(default)]
    pub pose: Option<String>,
    #[serde(default)]
    pub image_base64: Option<String>,
    #[serde(default)]
    pub text: Option<String>,
    #[serde(default)]
    pub reason: Option<String>,
    #[serde(default)]
    pub value: Option<bool>,
    #[serde(default)]
    pub country_code: Option<String>,
    #[serde(default)]
    pub consent: Option<Consent>,
    #[serde(default)]
    pub expected_revision: Option<f64>,
}
impl crate::model::Validate for Command {
    fn validate(&mut self) -> Result<()> {
        if uuid::Uuid::parse_str(&self.request_id).is_err() || self.request_id.len() != 36 {
            return Err(ApiError::invalid("requestID must be a UUID"));
        }
        if ![
            "consent",
            "identity",
            "listing",
            "enqueue",
            "cancel",
            "ready",
            "presence",
            "candidate",
            "submit",
            "leave",
            "report",
            "block",
            "unblock",
            "reply",
            "review",
            "withdrawCase",
            "withdrawAI",
            "withdrawSharing",
            "removeImages",
            "deleteAccount",
        ]
        .contains(&self.operation.as_str())
        {
            return Err(ApiError::invalid("Unknown Physique operation"));
        }
        if self.text.as_ref().is_some_and(|v| {
            v.chars().count() > 4000 || v.chars().any(|c| c.is_control() && c != '\n' && c != '\t')
        }) || self.reason.as_ref().is_some_and(|v| v.len() > 80)
            || self.match_id.as_ref().is_some_and(|v| v.len() > 128)
            || self.target_id.as_ref().is_some_and(|v| v.len() > 128)
            || self
                .image_base64
                .as_ref()
                .is_some_and(|v| v.len() > 1_398_104)
            || self
                .consent
                .as_ref()
                .is_some_and(|v| v.policy_version.len() > 128)
            || self
                .expected_revision
                .is_some_and(|v| !v.is_finite() || v < 0.0)
        {
            return Err(ApiError::invalid(
                "Physique request exceeds its field limits",
            ));
        }
        if self.image_base64.is_some() && self.operation != "candidate" {
            return Err(ApiError::invalid(
                "Images are accepted only by protected candidate intake",
            ));
        }
        if self
            .pose
            .as_ref()
            .is_some_and(|v| !super::competition::POSES.contains(&v.as_str()))
        {
            return Err(ApiError::invalid("Unknown Physique pose"));
        }
        Ok(())
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Page<T> {
    pub items: Vec<T>,
    pub cursor: Option<String>,
}
#[derive(Serialize)]
pub struct Items<T> {
    pub items: Vec<T>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Standing {
    pub id: String,
    pub position: Option<i64>,
    pub identity: Identity,
    pub record: Record,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CaseMessage {
    pub id: String,
    pub text: String,
    pub created_at: f64,
    pub from_staff: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Case {
    pub id: String,
    pub kind: String,
    pub status: String,
    pub summary: String,
    pub created_at: f64,
    pub updated_at: f64,
    #[serde(rename = "matchID")]
    pub match_id: Option<String>,
    pub decision: Option<String>,
    pub needs_reply: bool,
    pub can_appeal: bool,
    pub can_withdraw: bool,
    pub messages: Vec<CaseMessage>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Media {
    pub id: String,
    #[serde(rename = "ownerID")]
    pub owner_id: String,
    pub pose: String,
    pub status: String,
    pub image_base64: Option<String>,
    pub expires_at: Option<f64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrivacyReceipt {
    pub id: String,
    pub scope: String,
    pub status: String,
    pub created_at: f64,
    pub updated_at: f64,
    pub detail: String,
    pub retained_reason: Option<String>,
}
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BlockedPlayer {
    pub id: String,
    pub display_name: String,
}
