use crate::bridge::{self, Bridge, Failure};
use crate::{cli, schema};
use serde_json::{Map, Value, json};
use std::io::{BufRead, Write};

const DEFAULT_PROTOCOL: &str = "2024-11-05";

fn strip_extensions(value: &Value) -> Value {
    match value {
        Value::Object(map) => Value::Object(
            map.iter()
                .filter(|(key, _)| !key.starts_with("x-"))
                .map(|(key, child)| (key.clone(), strip_extensions(child)))
                .collect::<Map<String, Value>>(),
        ),
        Value::Array(items) => Value::Array(items.iter().map(strip_extensions).collect()),
        other => other.clone(),
    }
}

pub fn tool_listing(catalog: &[Value]) -> Value {
    let tools: Vec<Value> = catalog
        .iter()
        .map(|tool| {
            json!({
                "name": tool["name"],
                "description": tool["description"],
                "inputSchema": strip_extensions(&tool["inputSchema"]),
            })
        })
        .collect();
    json!({ "tools": tools })
}

fn text_result(value: &Value, is_error: bool) -> Value {
    let text = serde_json::to_string_pretty(value).unwrap_or_else(|_| "null".to_string());
    json!({ "content": [{ "type": "text", "text": text }], "isError": is_error })
}

struct Session {
    bridge: Option<Bridge>,
    catalog: Vec<Value>,
}

impl Session {
    fn bridge(&mut self) -> Result<&mut Bridge, Failure> {
        if self.bridge.is_none() {
            let mut bridge = Bridge::connect(&bridge::data_root(), true, true)?;
            self.catalog = bridge.catalog()?;
            self.bridge = Some(bridge);
        }
        Ok(self.bridge.as_mut().expect("bridge connected"))
    }

    fn drop_on_connection_loss(&mut self, failure: &Failure) {
        if failure.code == "app_unavailable" {
            self.bridge = None;
        }
    }

    fn list(&mut self) -> Result<Value, Failure> {
        self.bridge()?;
        Ok(tool_listing(&self.catalog))
    }

    fn call(&mut self, name: &str, mut arguments: Value) -> Result<Value, Failure> {
        self.bridge()?;
        let cwd = std::env::current_dir().unwrap_or_else(|_| "/".into());
        if let Some(tool) = schema::find(&self.catalog, name) {
            let tool = tool.clone();
            schema::absolutize_call(&tool, &mut arguments, &cwd, &self.catalog);
        }
        let bridge = self.bridge()?;
        let outcome = bridge.call(name, arguments, false, 120, 900);
        match outcome {
            Ok(reply) => Ok(cli::finish(&reply)),
            Err(failure) => {
                self.drop_on_connection_loss(&failure);
                Err(failure)
            }
        }
    }
}

fn reply(id: &Value, result: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "result": result })
}

fn rpc_error(id: &Value, code: i64, message: &str) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "error": { "code": code, "message": message } })
}

fn handle(session: &mut Session, message: &Value) -> Option<Value> {
    let id = message.get("id")?;
    let method = message["method"].as_str().unwrap_or("");
    let params = &message["params"];
    Some(match method {
        "initialize" => reply(
            id,
            json!({
                "protocolVersion": params["protocolVersion"].as_str().unwrap_or(DEFAULT_PROTOCOL),
                "capabilities": { "tools": { "listChanged": false } },
                "serverInfo": { "name": "tmax", "version": env!("CARGO_PKG_VERSION") },
                "instructions": "Call the context tool first. Media is attached by absolute path; Tmax copies it. Prefer batch for multi-step builds.",
            }),
        ),
        "ping" => reply(id, json!({})),
        "tools/list" => match session.list() {
            Ok(listing) => reply(id, listing),
            Err(failure) => rpc_error(id, -32000, &failure.message),
        },
        "tools/call" => {
            let name = params["name"].as_str().unwrap_or("");
            let arguments = if params["arguments"].is_object() { params["arguments"].clone() } else { json!({}) };
            match session.call(name, arguments) {
                Ok(value) => reply(id, text_result(&value, false)),
                Err(failure) => reply(id, text_result(&failure.to_value(), true)),
            }
        }
        _ => rpc_error(id, -32601, "Method not found."),
    })
}

pub fn serve() {
    let stdin = std::io::stdin();
    let mut stdout = std::io::stdout().lock();
    let mut session = Session { bridge: None, catalog: Vec::new() };
    for line in stdin.lock().lines() {
        let Ok(line) = line else { break };
        if line.trim().is_empty() {
            continue;
        }
        let response = match serde_json::from_str::<Value>(&line) {
            Ok(message) => handle(&mut session, &message),
            Err(_) => Some(rpc_error(&Value::Null, -32700, "Parse error.")),
        };
        if let Some(response) = response {
            if writeln!(stdout, "{response}").is_err() || stdout.flush().is_err() {
                break;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn listing_hides_tmax_extensions_and_keeps_schemas() {
        let catalog = vec![json!({
            "name": "attach_media",
            "description": "Attach files.",
            "risk": "write",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "media": {"type": "array", "items": {"type": "object", "properties": {"path": {"type": "string", "x-path": true}}}}
                },
                "required": ["media"]
            }
        })];
        let listing = tool_listing(&catalog);
        let schema = &listing["tools"][0]["inputSchema"];
        assert!(schema["properties"]["media"]["items"]["properties"]["path"].get("x-path").is_none());
        assert_eq!(schema["required"][0], "media");
        assert!(listing["tools"][0].get("risk").is_none());
    }

    #[test]
    fn handshake_and_unknown_methods_follow_jsonrpc() {
        let mut session = Session { bridge: None, catalog: Vec::new() };
        let init = handle(&mut session, &json!({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-03-26"}})).unwrap();
        assert_eq!(init["result"]["protocolVersion"], "2025-03-26");
        assert_eq!(init["result"]["serverInfo"]["name"], "tmax");
        let ping = handle(&mut session, &json!({"jsonrpc": "2.0", "id": 2, "method": "ping"})).unwrap();
        assert_eq!(ping["result"], json!({}));
        let unknown = handle(&mut session, &json!({"jsonrpc": "2.0", "id": 3, "method": "nope"})).unwrap();
        assert_eq!(unknown["error"]["code"], -32601);
        assert!(handle(&mut session, &json!({"jsonrpc": "2.0", "method": "notifications/initialized"})).is_none());
    }

    #[test]
    fn tool_failures_become_error_results_not_protocol_errors() {
        let value = text_result(&Failure::new("not_found", "No page.").to_value(), true);
        assert_eq!(value["isError"], true);
        assert!(value["content"][0]["text"].as_str().unwrap().contains("not_found"));
    }
}
