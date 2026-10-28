use serde_json::{Value, json};
use std::io::{BufRead, BufReader, ErrorKind, IsTerminal, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread::sleep;
use std::time::{Duration, Instant};

pub const PROTOCOL: u64 = 1;
const APP_BUNDLE_ID: &str = "com.timemaster.macos";
const STARTUP_SECONDS: u64 = 45;

#[derive(Debug, Clone)]
pub struct Failure {
    pub code: String,
    pub message: String,
    pub hint: Option<String>,
    pub details: Option<Value>,
}

impl Failure {
    pub fn new(code: &str, message: impl Into<String>) -> Self {
        Failure {
            code: code.to_string(),
            message: message.into(),
            hint: None,
            details: None,
        }
    }

    pub fn usage(message: impl Into<String>) -> Self {
        Failure::new("usage", message)
    }

    pub fn hint(mut self, hint: impl Into<String>) -> Self {
        self.hint = Some(hint.into());
        self
    }

    pub fn from_error(error: &Value) -> Self {
        Failure {
            code: error["code"].as_str().unwrap_or("failed").to_string(),
            message: error["message"].as_str().unwrap_or("The request failed.").to_string(),
            hint: error["hint"].as_str().map(str::to_string),
            details: error.get("details").cloned(),
        }
    }

    pub fn exit_code(&self) -> u8 {
        match self.code.as_str() {
            "usage" => 2,
            "forbidden" | "approval_denied" | "approval_timeout" => 3,
            "app_unavailable" | "app_not_ready" | "app_not_found" | "protocol_mismatch" => 4,
            "timeout" => 5,
            _ => 1,
        }
    }

    pub fn to_value(&self) -> Value {
        let mut error = json!({ "code": self.code, "message": self.message });
        if let Some(hint) = &self.hint {
            error["hint"] = json!(hint);
        }
        if let Some(details) = &self.details {
            error["details"] = details.clone();
        }
        json!({ "ok": false, "error": error })
    }
}

pub fn data_root() -> PathBuf {
    if let Some(root) = std::env::var_os("TIMEMASTER_DATA_ROOT") {
        if !root.is_empty() {
            return PathBuf::from(root);
        }
    }
    let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"));
    home.join("Library/Application Support/TimeMaster")
}

pub fn read_discovery(root: &Path) -> Option<Value> {
    let text = std::fs::read_to_string(root.join(".agent/bridge.json")).ok()?;
    serde_json::from_str(&text).ok()
}

fn open_stream(root: &Path) -> Option<UnixStream> {
    let info = read_discovery(root)?;
    UnixStream::connect(info.get("socket")?.as_str()?).ok()
}

fn launch_app() -> Result<(), Failure> {
    let mut command = Command::new("/usr/bin/open");
    command.arg("-g");
    match std::env::var("TMAX_APP") {
        Ok(path) if !path.is_empty() => {
            command.arg(path);
        }
        _ => {
            command.args(["-b", APP_BUNDLE_ID]);
        }
    }
    let status = command
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|error| Failure::new("app_not_found", format!("Could not run open: {error}")))?;
    if status.success() {
        Ok(())
    } else {
        Err(Failure::new("app_not_found", "Tmax could not be opened.")
            .hint("Install Tmax, or set TMAX_APP to the path of Tmax.app."))
    }
}

pub struct Bridge {
    reader: BufReader<UnixStream>,
    next_id: u64,
    pub hello: Value,
}

impl Bridge {
    pub fn connect(root: &Path, launch: bool, wait_ready: bool) -> Result<Bridge, Failure> {
        let deadline = Instant::now() + Duration::from_secs(STARTUP_SECONDS);
        let mut launched = false;
        let stream = loop {
            if let Some(stream) = open_stream(root) {
                break stream;
            }
            if !launch {
                return Err(Failure::new("app_unavailable", "Tmax is not running.")
                    .hint("Open Tmax, or run the command without --no-launch."));
            }
            if !launched {
                if std::io::stderr().is_terminal() {
                    eprintln!("Opening Tmax…");
                }
                launch_app()?;
                launched = true;
            }
            if Instant::now() > deadline {
                return Err(Failure::new("app_unavailable", "Tmax did not start listening for agents.")
                    .hint("Check that Settings → Agent Access is not Off."));
            }
            sleep(Duration::from_millis(150));
        };
        let mut bridge = Bridge {
            reader: BufReader::new(stream),
            next_id: 1,
            hello: Value::Null,
        };
        loop {
            let reply = bridge.rpc("hello", json!({}), 10)?;
            let hello = reply["result"].clone();
            if hello["protocol"].as_u64() != Some(PROTOCOL) {
                return Err(Failure::new("protocol_mismatch", "This tmax and Tmax speak different protocols.")
                    .hint("Update Tmax and the tmax command together."));
            }
            let ready = hello["ready"].as_bool().unwrap_or(false);
            bridge.hello = hello;
            if ready || !wait_ready {
                return Ok(bridge);
            }
            if Instant::now() > deadline {
                return Err(Failure::new("app_not_ready", "Tmax is still opening.").hint("Try again in a few seconds."));
            }
            sleep(Duration::from_millis(250));
        }
    }

    pub fn rpc(&mut self, method: &str, params: Value, timeout_seconds: u64) -> Result<Value, Failure> {
        let id = self.next_id;
        self.next_id += 1;
        let mut line = serde_json::to_string(&json!({ "id": id, "method": method, "params": params }))
            .map_err(|error| Failure::new("failed", error.to_string()))?;
        line.push('\n');
        let stream = self.reader.get_ref();
        stream
            .set_read_timeout(Some(Duration::from_secs(timeout_seconds.max(1))))
            .map_err(|error| Failure::new("app_unavailable", error.to_string()))?;
        let mut writer = stream;
        writer
            .write_all(line.as_bytes())
            .map_err(|_| Failure::new("app_unavailable", "Tmax closed the connection."))?;
        let mut response = String::new();
        match self.reader.read_line(&mut response) {
            Ok(0) => Err(Failure::new("app_unavailable", "Tmax closed the connection.")),
            Ok(_) => {
                let value: Value = serde_json::from_str(&response)
                    .map_err(|error| Failure::new("failed", format!("Unreadable reply from Tmax: {error}")))?;
                if value["ok"].as_bool() == Some(true) {
                    Ok(value)
                } else {
                    Err(Failure::from_error(&value["error"]))
                }
            }
            Err(error) if matches!(error.kind(), ErrorKind::WouldBlock | ErrorKind::TimedOut) => Err(Failure::new(
                "timeout",
                format!("No reply from Tmax within {timeout_seconds} seconds."),
            )
            .hint("Raise --timeout, or check for an approval prompt in Tmax.")),
            Err(error) => Err(Failure::new("app_unavailable", format!("Connection to Tmax failed: {error}"))),
        }
    }

    pub fn catalog(&mut self) -> Result<Vec<Value>, Failure> {
        let reply = self.rpc("tools.list", json!({}), 15)?;
        Ok(reply["result"]["tools"].as_array().cloned().unwrap_or_default())
    }

    pub fn call(
        &mut self,
        name: &str,
        arguments: Value,
        dry_run: bool,
        wait_seconds: u64,
        timeout_seconds: u64,
    ) -> Result<Value, Failure> {
        self.rpc(
            "tools.call",
            json!({ "name": name, "arguments": arguments, "dryRun": dry_run, "wait": wait_seconds }),
            timeout_seconds,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufRead, BufReader, Write};
    use std::os::unix::net::UnixListener;

    fn temp_root(tag: &str) -> PathBuf {
        let root = std::env::temp_dir().join(format!("tmax-test-{tag}-{}", std::process::id()));
        std::fs::create_dir_all(root.join(".agent")).unwrap();
        root
    }

    fn serve(root: &Path, replies: Vec<String>) -> std::thread::JoinHandle<()> {
        let socket = root.join(".agent/bridge.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        std::fs::write(
            root.join(".agent/bridge.json"),
            json!({ "socket": socket.to_str().unwrap(), "pid": 1 }).to_string(),
        )
        .unwrap();
        std::thread::spawn(move || {
            let (stream, _) = listener.accept().unwrap();
            let mut reader = BufReader::new(stream.try_clone().unwrap());
            let mut writer = stream;
            for reply in replies {
                let mut line = String::new();
                if reader.read_line(&mut line).unwrap() == 0 {
                    return;
                }
                let request: Value = serde_json::from_str(&line).unwrap();
                let mut value: Value = serde_json::from_str(&reply).unwrap();
                value["id"] = request["id"].clone();
                writer.write_all(format!("{value}\n").as_bytes()).unwrap();
            }
        })
    }

    #[test]
    fn waits_for_ready_and_rejects_other_protocols() {
        let root = temp_root("ready");
        let handle = serve(
            &root,
            vec![
                r#"{"ok":true,"result":{"protocol":1,"ready":false}}"#.to_string(),
                r#"{"ok":true,"result":{"protocol":1,"ready":true,"access":"standard"}}"#.to_string(),
                r#"{"ok":true,"result":{"tools":[{"name":"context"}]}}"#.to_string(),
            ],
        );
        let mut bridge = Bridge::connect(&root, false, true).unwrap();
        assert_eq!(bridge.hello["access"], "standard");
        assert_eq!(bridge.catalog().unwrap().len(), 1);
        handle.join().unwrap();

        let other = temp_root("protocol");
        let handle = serve(&other, vec![r#"{"ok":true,"result":{"protocol":99,"ready":true}}"#.to_string()]);
        let failure = Bridge::connect(&other, false, true).err().unwrap();
        assert_eq!(failure.code, "protocol_mismatch");
        assert_eq!(failure.exit_code(), 4);
        handle.join().unwrap();
    }

    #[test]
    fn maps_error_replies_to_failures_and_exit_codes() {
        let root = temp_root("errors");
        let handle = serve(
            &root,
            vec![
                r#"{"ok":true,"result":{"protocol":1,"ready":true}}"#.to_string(),
                r#"{"ok":false,"error":{"code":"forbidden","message":"No.","hint":"Change it."}}"#.to_string(),
            ],
        );
        let mut bridge = Bridge::connect(&root, false, true).unwrap();
        let failure = bridge.call("delete_page", json!({}), false, 5, 5).err().unwrap();
        assert_eq!(failure.code, "forbidden");
        assert_eq!(failure.hint.as_deref(), Some("Change it."));
        assert_eq!(failure.exit_code(), 3);
        assert_eq!(failure.to_value()["error"]["message"], "No.");
        handle.join().unwrap();
    }

    #[test]
    fn reports_a_missing_app_without_launching() {
        let root = temp_root("missing");
        let failure = Bridge::connect(&root, false, true).err().unwrap();
        assert_eq!(failure.code, "app_unavailable");
        assert_eq!(failure.exit_code(), 4);
        assert_eq!(Failure::usage("x").exit_code(), 2);
        assert_eq!(Failure::new("timeout", "x").exit_code(), 5);
        assert_eq!(Failure::new("not_found", "x").exit_code(), 1);
    }
}
