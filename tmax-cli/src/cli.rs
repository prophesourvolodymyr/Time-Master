use crate::bridge::{self, Bridge, Failure};
use crate::{mcp, schema};
use serde_json::{Value, json};
use std::io::{IsTerminal, Read};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const HELP: &str = "tmax — drive the Tmax app from the command line or an AI agent

Usage:
  tmax context                     what is in the library and the conventions to follow
  tmax tools [--json]              list every tool
  tmax <tool> [options]            run one tool (tmax <tool> --help for its options)
  tmax <tool> --json '{...}'       pass arguments as JSON ('-' reads stdin)
  tmax batch plan.json             run many operations; all roll back if one fails
  tmax undo [batch]                reverse the last agent batch
  tmax doctor                      check the connection to Tmax
  tmax install                     link tmax into ~/.local/bin
  tmax mcp                         serve the tools over MCP (stdio)

Options:
  --dry-run        validate and preview without changing anything
  --wait SECONDS   how long to wait for an approval prompt in Tmax (default 120)
  --timeout SECONDS  how long to wait for the whole call (default 900)
  --no-launch      fail instead of opening Tmax when it is not running
  --key value      any tool property, written in kebab-case (--if-exists reuse)
                   repeat a flag to build a list; @file reads text from a file;
                   use --key=value when a value starts with --

Output is JSON on stdout. Exit codes: 0 ok, 1 tool error, 2 usage,
3 not allowed / declined, 4 Tmax unavailable, 5 timeout.
";

struct Options {
    dry_run: bool,
    no_launch: bool,
    help: bool,
    wait: Option<u64>,
    timeout: Option<u64>,
    json: Option<String>,
    flags: Vec<(String, Option<String>)>,
    positional: Vec<String>,
}

fn number(name: &str, value: Option<String>) -> Result<u64, Failure> {
    value
        .as_deref()
        .and_then(|text| text.trim().parse::<u64>().ok())
        .ok_or_else(|| Failure::usage(format!("--{name} takes a number of seconds.")))
}

fn parse(tokens: &[String]) -> Result<Options, Failure> {
    let mut options = Options {
        dry_run: false,
        no_launch: false,
        help: false,
        wait: None,
        timeout: None,
        json: None,
        flags: Vec::new(),
        positional: Vec::new(),
    };
    let mut index = 0;
    while index < tokens.len() {
        let token = &tokens[index];
        index += 1;
        if token == "-h" {
            options.help = true;
            continue;
        }
        let Some(body) = token.strip_prefix("--") else {
            options.positional.push(token.clone());
            continue;
        };
        if body.is_empty() {
            options.positional.extend(tokens[index..].iter().cloned());
            break;
        }
        let (name, inline) = match body.split_once('=') {
            Some((name, value)) => (name, Some(value.to_string())),
            None => (body, None),
        };
        match name {
            "dry-run" => {
                options.dry_run = true;
                continue;
            }
            "no-launch" => {
                options.no_launch = true;
                continue;
            }
            "help" => {
                options.help = true;
                continue;
            }
            _ => {}
        }
        let value = match inline {
            Some(value) => Some(value),
            None => match tokens.get(index) {
                Some(next) if !next.starts_with("--") => {
                    index += 1;
                    Some(next.clone())
                }
                _ => None,
            },
        };
        match name {
            "wait" => options.wait = Some(number(name, value)?),
            "timeout" => options.timeout = Some(number(name, value)?),
            "json" => options.json = value,
            _ => options.flags.push((name.to_string(), value)),
        }
    }
    Ok(options)
}

fn read_stdin() -> Result<String, Failure> {
    let mut text = String::new();
    std::io::stdin()
        .read_to_string(&mut text)
        .map_err(|error| Failure::usage(format!("Could not read stdin: {error}")))?;
    Ok(text)
}

fn json_base(options: &Options) -> Result<Option<Value>, Failure> {
    let Some(source) = &options.json else { return Ok(None) };
    let text = if source == "-" { read_stdin()? } else { source.clone() };
    serde_json::from_str(&text)
        .map(Some)
        .map_err(|error| Failure::usage(format!("--json is not valid JSON: {error}")))
}

fn working_directory() -> PathBuf {
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("/"))
}

fn connect(options: &Options) -> Result<Bridge, Failure> {
    Bridge::connect(&bridge::data_root(), !options.no_launch, true)
}

fn unknown_tool(name: &str, catalog: &[Value]) -> Failure {
    let wanted = schema::normalize(name);
    let mut close: Vec<&str> = catalog
        .iter()
        .filter_map(|tool| tool["name"].as_str())
        .filter(|candidate| {
            let normal = schema::normalize(candidate);
            !wanted.is_empty() && (normal.contains(&wanted) || wanted.contains(&normal))
        })
        .collect();
    close.truncate(4);
    let hint = if close.is_empty() {
        "Run tmax tools to list what is available.".to_string()
    } else {
        format!("Did you mean: {}?", close.join(", "))
    };
    Failure::new("unknown_tool", format!("Unknown tool '{name}'.")).hint(hint)
}

fn call_timeouts(options: &Options) -> (u64, u64) {
    let wait = options.wait.unwrap_or(120);
    let timeout = options.timeout.unwrap_or(900).max(wait + 30);
    (wait, timeout)
}

pub fn finish(reply: &Value) -> Value {
    let mut result = reply["result"].clone();
    if let (Some(batch), Some(map)) = (reply["batch"].as_str(), result.as_object_mut()) {
        map.insert("batch".to_string(), json!(batch));
    }
    result
}

fn tool_help(tool: &Value) -> String {
    let name = tool["name"].as_str().unwrap_or("");
    let mut text = format!(
        "tmax {name} — {}\nRisk: {}\n",
        tool["description"].as_str().unwrap_or(""),
        tool["risk"].as_str().unwrap_or("read")
    );
    let required: Vec<&str> = tool["inputSchema"]["required"]
        .as_array()
        .map(|list| list.iter().filter_map(Value::as_str).collect())
        .unwrap_or_default();
    match schema::properties(tool) {
        Some(properties) if !properties.is_empty() => {
            text.push_str("Options:\n");
            for (key, property) in properties {
                let kind = match property["type"].as_str().unwrap_or("string") {
                    "array" => format!("list of {}", property["items"]["type"].as_str().unwrap_or("string")),
                    other => other.to_string(),
                };
                let marker = if required.contains(&key.as_str()) { " (required)" } else { "" };
                text.push_str(&format!(
                    "  --{} <{kind}>{marker}  {}\n",
                    schema::kebab(key),
                    property["description"].as_str().unwrap_or("")
                ));
            }
        }
        _ => text.push_str("This tool takes no arguments.\n"),
    }
    text
}

fn call_tool(name: &str, rest: &[String]) -> Result<Option<Value>, Failure> {
    let name = name.replace('-', "_");
    let options = parse(rest)?;
    let cwd = working_directory();
    let mut bridge = connect(&options)?;
    let catalog = bridge.catalog()?;
    let Some(tool) = schema::find(&catalog, &name) else {
        return Err(unknown_tool(&name, &catalog));
    };
    if options.help {
        print!("{}", tool_help(tool));
        return Ok(None);
    }
    if let Some(extra) = options.positional.first() {
        return Err(Failure::usage(format!("Unexpected argument '{extra}'."))
            .hint("Tool options start with --; use --key=value if a value starts with --."));
    }
    let mut arguments = schema::build(tool, json_base(&options)?, &options.flags, &cwd)?;
    schema::absolutize_call(tool, &mut arguments, &cwd, &catalog);
    let (wait, timeout) = call_timeouts(&options);
    let reply = bridge.call(&name, arguments, options.dry_run, wait, timeout)?;
    Ok(Some(finish(&reply)))
}

fn batch(rest: &[String]) -> Result<Option<Value>, Failure> {
    let options = parse(rest)?;
    let Some(source) = options.positional.first() else {
        return Err(Failure::usage("tmax batch needs a plan file, or - for stdin.")
            .hint("The plan is {\"operations\":[{\"tool\":\"create_exercise_page\",\"arguments\":{…}}]} or just the array."));
    };
    let (text, base) = if source == "-" {
        (read_stdin()?, working_directory())
    } else {
        let location = schema::expand(source, &working_directory());
        let text = std::fs::read_to_string(&location)
            .map_err(|error| Failure::usage(format!("Could not read {}: {error}", location.display())))?;
        let base = location.parent().map(Path::to_path_buf).unwrap_or_else(working_directory);
        (text, base)
    };
    let parsed: Value = serde_json::from_str(&text)
        .map_err(|error| Failure::usage(format!("The plan is not valid JSON: {error}")))?;
    let mut arguments = if parsed.is_array() { json!({ "operations": parsed }) } else { parsed };
    let mut bridge = connect(&options)?;
    let catalog = bridge.catalog()?;
    let Some(tool) = schema::find(&catalog, "batch") else {
        return Err(unknown_tool("batch", &catalog));
    };
    schema::absolutize_call(tool, &mut arguments, &base, &catalog);
    let (wait, timeout) = call_timeouts(&options);
    let reply = bridge.call("batch", arguments, options.dry_run, wait, timeout)?;
    Ok(Some(finish(&reply)))
}

fn undo(rest: &[String]) -> Result<Option<Value>, Failure> {
    let options = parse(rest)?;
    let mut arguments = json!({});
    if let Some(id) = options.positional.first() {
        arguments["batch"] = json!(id);
    }
    let mut bridge = connect(&options)?;
    let (wait, timeout) = call_timeouts(&options);
    let reply = bridge.call("undo", arguments, options.dry_run, wait, timeout)?;
    Ok(Some(finish(&reply)))
}

fn tools(rest: &[String]) -> Result<Option<Value>, Failure> {
    let options = parse(rest)?;
    let mut bridge = connect(&options)?;
    let catalog = bridge.catalog()?;
    let as_json = options.flags.iter().any(|(flag, _)| flag == "json") || options.json.is_some();
    if as_json {
        return Ok(Some(Value::Array(catalog)));
    }
    let width = catalog.iter().filter_map(|tool| tool["name"].as_str()).map(str::len).max().unwrap_or(0);
    for tool in &catalog {
        let description = tool["description"].as_str().unwrap_or("");
        let first = description.split(". ").next().unwrap_or(description);
        println!(
            "{:<width$}  {:<11}  {}",
            tool["name"].as_str().unwrap_or(""),
            tool["risk"].as_str().unwrap_or(""),
            first.trim_end_matches('.')
        );
    }
    Ok(None)
}

fn doctor(rest: &[String]) -> Result<Option<Value>, Failure> {
    let options = parse(rest)?;
    let root = bridge::data_root();
    let discovery = bridge::read_discovery(&root);
    let mut report = json!({
        "cli": env!("CARGO_PKG_VERSION"),
        "dataRoot": root.to_string_lossy(),
        "discovery": discovery.is_some(),
    });
    match Bridge::connect(&root, false, false) {
        Ok(bridge) => {
            let hello = bridge.hello.clone();
            report["running"] = json!(true);
            report["ready"] = hello["ready"].clone();
            report["access"] = hello["access"].clone();
            report["app"] = json!(format!(
                "{} {}",
                hello["app"].as_str().unwrap_or("Tmax"),
                hello["version"].as_str().unwrap_or("")
            ).trim());
            report["schema"] = hello["schema"].clone();
            report["tools"] = hello["tools"].clone();
            report["pid"] = hello["pid"].clone();
            if hello["ready"].as_bool() != Some(true) {
                report["hint"] = json!("Tmax is still opening; try again in a few seconds.");
                print_value(&report);
                return Err(Failure::new("app_not_ready", "Tmax is still opening."));
            }
            Ok(Some(report))
        }
        Err(failure) => {
            report["running"] = json!(false);
            report["hint"] = json!(failure.hint.clone().unwrap_or_else(|| failure.message.clone()));
            if !options.no_launch {
                report["note"] = json!("Any other tmax command opens Tmax automatically.");
            }
            print_value(&report);
            Err(failure)
        }
    }
}

fn install(rest: &[String]) -> Result<Option<Value>, Failure> {
    let options = parse(rest)?;
    let directory = options
        .flags
        .iter()
        .find(|(flag, _)| flag == "dir")
        .and_then(|(_, value)| value.clone())
        .map(|value| schema::expand(&value, &working_directory()))
        .unwrap_or_else(|| {
            std::env::var_os("HOME")
                .map(|home| PathBuf::from(home).join(".local/bin"))
                .unwrap_or_else(|| PathBuf::from("/usr/local/bin"))
        });
    let executable = std::env::current_exe()
        .and_then(std::fs::canonicalize)
        .map_err(|error| Failure::new("failed", format!("Cannot locate this executable: {error}")))?;
    std::fs::create_dir_all(&directory)
        .map_err(|error| Failure::new("failed", format!("Cannot create {}: {error}", directory.display())))?;
    let link = directory.join("tmax");
    match std::fs::symlink_metadata(&link) {
        Ok(metadata) if metadata.file_type().is_symlink() => {
            if std::fs::canonicalize(&link).ok().as_deref() != Some(executable.as_path()) {
                std::fs::remove_file(&link)
                    .map_err(|error| Failure::new("failed", format!("Cannot replace {}: {error}", link.display())))?;
            }
        }
        Ok(_) => {
            return Err(Failure::new("already_exists", format!("{} exists and is not a link.", link.display()))
                .hint("Remove it first, or use --dir to choose another folder."));
        }
        Err(_) => {}
    }
    if std::fs::symlink_metadata(&link).is_err() {
        std::os::unix::fs::symlink(&executable, &link)
            .map_err(|error| Failure::new("failed", format!("Cannot create {}: {error}", link.display())))?;
    }
    let on_path = std::env::var_os("PATH")
        .map(|paths| std::env::split_paths(&paths).any(|entry| entry == directory))
        .unwrap_or(false);
    let mut report = json!({ "installed": link.to_string_lossy(), "target": executable.to_string_lossy(), "onPath": on_path });
    if !on_path {
        report["hint"] = json!(format!("Add {} to your PATH.", directory.display()));
    }
    Ok(Some(report))
}

fn print_value(value: &Value) {
    let text = if std::io::stdout().is_terminal() {
        serde_json::to_string_pretty(value)
    } else {
        serde_json::to_string(value)
    };
    println!("{}", text.unwrap_or_else(|_| "null".to_string()));
}

fn execute(args: &[String]) -> Result<Option<Value>, Failure> {
    let Some(command) = args.first() else {
        print!("{HELP}");
        return Ok(None);
    };
    let rest = &args[1..];
    match command.as_str() {
        "help" | "--help" | "-h" => {
            print!("{HELP}");
            Ok(None)
        }
        "--version" | "-V" | "version" => {
            println!("tmax {}", env!("CARGO_PKG_VERSION"));
            Ok(None)
        }
        "doctor" => doctor(rest),
        "tools" => tools(rest),
        "install" => install(rest),
        "batch" => batch(rest),
        "undo" => undo(rest),
        "mcp" => {
            mcp::serve();
            Ok(None)
        }
        name if name.starts_with('-') => Err(Failure::usage(format!("Unknown option {name}.")).hint("Run tmax --help.")),
        name => call_tool(name, rest),
    }
}

pub fn run(args: Vec<String>) -> ExitCode {
    match execute(&args) {
        Ok(Some(value)) => {
            print_value(&value);
            ExitCode::SUCCESS
        }
        Ok(None) => ExitCode::SUCCESS,
        Err(failure) => {
            if failure.code != "app_not_ready" || !std::io::stdout().is_terminal() {
                print_value(&failure.to_value());
            }
            if std::io::stderr().is_terminal() {
                match &failure.hint {
                    Some(hint) => eprintln!("tmax: {} ({hint})", failure.message),
                    None => eprintln!("tmax: {}", failure.message),
                }
            }
            ExitCode::from(failure.exit_code())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn strings(items: &[&str]) -> Vec<String> {
        items.iter().map(|item| item.to_string()).collect()
    }

    #[test]
    fn control_flags_never_swallow_the_next_token() {
        let options = parse(&strings(&["--dry-run", "plan.json", "--wait", "30", "--no-launch"])).unwrap();
        assert!(options.dry_run && options.no_launch);
        assert_eq!(options.positional, vec!["plan.json"]);
        assert_eq!(options.wait, Some(30));
    }

    #[test]
    fn tool_flags_take_values_or_stand_alone() {
        let options = parse(&strings(&["--title", "Push Up", "--sets=3", "--include-media", "--json", "{}"])).unwrap();
        assert_eq!(
            options.flags,
            vec![
                ("title".to_string(), Some("Push Up".to_string())),
                ("sets".to_string(), Some("3".to_string())),
                ("include-media".to_string(), None),
            ]
        );
        assert_eq!(options.json.as_deref(), Some("{}"));
    }

    #[test]
    fn values_that_start_with_dashes_need_the_equals_form() {
        let options = parse(&strings(&["--note=--- cue ---", "--other"])).unwrap();
        assert_eq!(options.flags[0].1.as_deref(), Some("--- cue ---"));
        assert_eq!(options.flags[1], ("other".to_string(), None));
    }

    #[test]
    fn bad_wait_values_are_usage_errors() {
        assert_eq!(parse(&strings(&["--wait", "soon"])).err().unwrap().exit_code(), 2);
        assert_eq!(parse(&strings(&["--timeout"])).err().unwrap().exit_code(), 2);
    }

    #[test]
    fn timeouts_always_outlast_the_approval_wait() {
        let options = parse(&strings(&["--wait", "600", "--timeout", "100"])).unwrap();
        assert_eq!(call_timeouts(&options), (600, 630));
        assert_eq!(call_timeouts(&parse(&[]).unwrap()), (120, 900));
    }

    #[test]
    fn batch_envelope_is_folded_into_the_result() {
        let reply = json!({"ok": true, "result": {"created": 2}, "batch": "ab12cd34"});
        assert_eq!(finish(&reply), json!({"created": 2, "batch": "ab12cd34"}));
        assert_eq!(finish(&json!({"ok": true, "result": {"n": 1}})), json!({"n": 1}));
    }

    #[test]
    fn unknown_tools_suggest_close_names() {
        let catalog = vec![json!({"name": "create_exercise_page"}), json!({"name": "list_pages"})];
        let failure = unknown_tool("create_exercise", &catalog);
        assert_eq!(failure.code, "unknown_tool");
        assert!(failure.hint.unwrap().contains("create_exercise_page"));
    }
}
