use crate::bridge::Failure;
use serde_json::{Map, Value};
use std::path::{Path, PathBuf};

pub fn find<'a>(catalog: &'a [Value], name: &str) -> Option<&'a Value> {
    catalog.iter().find(|tool| tool["name"] == name)
}

pub fn properties(tool: &Value) -> Option<&Map<String, Value>> {
    tool.get("inputSchema")?.get("properties")?.as_object()
}

pub fn normalize(name: &str) -> String {
    name.chars()
        .filter(|character| character.is_ascii_alphanumeric())
        .map(|character| character.to_ascii_lowercase())
        .collect()
}

pub fn kebab(name: &str) -> String {
    let mut output = String::with_capacity(name.len() + 4);
    let mut previous_lower = false;
    for character in name.chars() {
        if character.is_ascii_uppercase() {
            if previous_lower {
                output.push('-');
            }
            output.push(character.to_ascii_lowercase());
            previous_lower = false;
        } else if character == '_' {
            output.push('-');
            previous_lower = false;
        } else {
            output.push(character);
            previous_lower = character.is_ascii_lowercase() || character.is_ascii_digit();
        }
    }
    output
}

fn resolve<'a>(tool: &'a Value, flag: &str) -> Option<(&'a String, &'a Value)> {
    let wanted = normalize(flag);
    properties(tool)?.iter().find(|(name, _)| normalize(name) == wanted)
}

fn schema_type(schema: &Value) -> &str {
    schema["type"].as_str().unwrap_or("string")
}

fn read_text(value: &str, cwd: &Path) -> Result<String, Failure> {
    if let Some(literal) = value.strip_prefix("@@") {
        return Ok(format!("@{literal}"));
    }
    if let Some(path) = value.strip_prefix('@') {
        let location = expand(path, cwd);
        return std::fs::read_to_string(&location).map_err(|error| {
            Failure::usage(format!("Could not read {}: {error}", location.display()))
        });
    }
    Ok(value.to_string())
}

fn parse_json(text: &str, flag: &str) -> Result<Value, Failure> {
    serde_json::from_str(text)
        .map_err(|error| Failure::usage(format!("--{flag} needs valid JSON: {error}")))
}

pub fn coerce(flag: &str, value: Option<&str>, schema: &Value, cwd: &Path) -> Result<Value, Failure> {
    let kind = schema_type(schema);
    if kind == "boolean" {
        return match value {
            None => Ok(Value::Bool(true)),
            Some("true" | "yes" | "1" | "on") => Ok(Value::Bool(true)),
            Some("false" | "no" | "0" | "off") => Ok(Value::Bool(false)),
            Some(other) => Err(Failure::usage(format!("--{flag} takes true or false, not '{other}'."))),
        };
    }
    let text = value.ok_or_else(|| Failure::usage(format!("--{flag} needs a value.")))?;
    match kind {
        "integer" => text
            .trim()
            .parse::<i64>()
            .map(Value::from)
            .map_err(|_| Failure::usage(format!("--{flag} takes a whole number, not '{text}'."))),
        "number" => text
            .trim()
            .parse::<f64>()
            .ok()
            .and_then(|number| serde_json::Number::from_f64(number))
            .map(Value::Number)
            .ok_or_else(|| Failure::usage(format!("--{flag} takes a number, not '{text}'."))),
        "object" => parse_json(&read_text(text, cwd)?, flag),
        "array" => {
            let items = &schema["items"];
            match schema_type(items) {
                "object" | "array" => {
                    let shorthand = items["properties"].get("path").is_some()
                        && !text.trim_start().starts_with(['{', '[', '@']);
                    if shorthand {
                        Ok(serde_json::json!({ "path": text }))
                    } else {
                        parse_json(&read_text(text, cwd)?, flag)
                    }
                }
                _ => coerce(flag, Some(text), items, cwd),
            }
        }
        _ => Ok(Value::String(read_text(text, cwd)?)),
    }
}

pub fn build(
    tool: &Value,
    base: Option<Value>,
    flags: &[(String, Option<String>)],
    cwd: &Path,
) -> Result<Value, Failure> {
    let mut arguments = match base {
        Some(Value::Object(map)) => map,
        Some(_) => return Err(Failure::usage("--json must be a JSON object.")),
        None => Map::new(),
    };
    for (flag, value) in flags {
        let Some((name, schema)) = resolve(tool, flag) else {
            let allowed: Vec<String> = properties(tool)
                .map(|map| map.keys().map(|key| format!("--{}", kebab(key))).collect())
                .unwrap_or_default();
            let hint = if allowed.is_empty() {
                "This tool takes no arguments.".to_string()
            } else {
                format!("Allowed: {}", allowed.join(", "))
            };
            return Err(Failure::usage(format!(
                "Unknown option --{flag} for {}.",
                tool["name"].as_str().unwrap_or("this tool")
            ))
            .hint(hint));
        };
        let parsed = coerce(flag, value.as_deref(), schema, cwd)?;
        if schema_type(schema) == "array" {
            let slot = arguments
                .entry(name.clone())
                .or_insert_with(|| Value::Array(Vec::new()));
            if !slot.is_array() {
                *slot = Value::Array(Vec::new());
            }
            if let Some(list) = slot.as_array_mut() {
                match parsed {
                    Value::Array(items) => list.extend(items),
                    other => list.push(other),
                }
            }
        } else {
            arguments.insert(name.clone(), parsed);
        }
    }
    Ok(Value::Object(arguments))
}

pub fn expand(path: &str, cwd: &Path) -> PathBuf {
    let expanded = if path == "~" {
        std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from(path))
    } else if let Some(rest) = path.strip_prefix("~/") {
        std::env::var_os("HOME")
            .map(|home| PathBuf::from(home).join(rest))
            .unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    };
    let absolute = if expanded.is_absolute() { expanded } else { cwd.join(expanded) };
    std::fs::canonicalize(&absolute).unwrap_or(absolute)
}

pub fn absolutize(value: &mut Value, schema: &Value, cwd: &Path, catalog: &[Value]) {
    if schema["x-path"].as_bool() == Some(true) {
        if let Value::String(text) = value {
            if !text.contains("://") && !text.is_empty() {
                *text = expand(text, cwd).to_string_lossy().into_owned();
            }
        }
        return;
    }
    match value {
        Value::Object(map) => {
            if let Some(props) = schema.get("properties").and_then(Value::as_object) {
                for (key, child) in map.iter_mut() {
                    if let Some(child_schema) = props.get(key) {
                        absolutize(child, child_schema, cwd, catalog);
                    }
                }
            }
        }
        Value::Array(items) => {
            let item_schema = &schema["items"];
            for item in items {
                absolutize(item, item_schema, cwd, catalog);
            }
        }
        _ => {}
    }
}

pub fn absolutize_call(tool: &Value, arguments: &mut Value, cwd: &Path, catalog: &[Value]) {
    if let Some(schema) = tool.get("inputSchema") {
        absolutize(arguments, schema, cwd, catalog);
    }
    if tool["name"] == "batch" {
        if let Some(operations) = arguments.get_mut("operations").and_then(Value::as_array_mut) {
            for operation in operations {
                let name = operation["tool"].as_str().or_else(|| operation["name"].as_str()).map(str::to_string);
                if let (Some(name), Some(inner)) = (name, operation.get_mut("arguments")) {
                    if let Some(inner_tool) = find(catalog, &name) {
                        absolutize_call(inner_tool, inner, cwd, catalog);
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn tool() -> Value {
        json!({
            "name": "create_exercise_page",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "ifExists": {"type": "string"},
                    "sets": {"type": "integer"},
                    "dryRun": {"type": "boolean"},
                    "links": {"type": "array", "items": {"type": "string"}},
                    "media": {"type": "array", "items": {"type": "object", "properties": {
                        "path": {"type": "string", "x-path": true},
                        "comment": {"type": "string"}
                    }}},
                    "cover": {"type": "string", "x-path": true}
                }
            }
        })
    }

    fn flags(items: &[(&str, Option<&str>)]) -> Vec<(String, Option<String>)> {
        items.iter().map(|(key, value)| (key.to_string(), value.map(str::to_string))).collect()
    }

    #[test]
    fn flags_match_properties_by_normalized_name_and_coerce_types() {
        let cwd = Path::new("/");
        let built = build(
            &tool(),
            None,
            &flags(&[("title", Some("Push Up")), ("if-exists", Some("reuse")), ("sets", Some("3")), ("dry-run", None)]),
            cwd,
        )
        .unwrap();
        assert_eq!(built, json!({"title": "Push Up", "ifExists": "reuse", "sets": 3, "dryRun": true}));
    }

    #[test]
    fn repeated_flags_build_arrays_and_json_base_is_extended() {
        let cwd = Path::new("/");
        let built = build(
            &tool(),
            Some(json!({"links": ["https://a.example"], "title": "Base"})),
            &flags(&[("links", Some("https://b.example")), ("media", Some(r#"{"path":"a.jpg"}"#)), ("media", Some(r#"[{"path":"b.jpg"}]"#))]),
            cwd,
        )
        .unwrap();
        assert_eq!(built["links"], json!(["https://a.example", "https://b.example"]));
        assert_eq!(built["media"], json!([{"path": "a.jpg"}, {"path": "b.jpg"}]));
        assert_eq!(built["title"], "Base");
    }

    #[test]
    fn unknown_flags_list_the_allowed_ones_and_bad_numbers_are_usage_errors() {
        let cwd = Path::new("/");
        let unknown = build(&tool(), None, &flags(&[("titel", Some("x"))]), cwd).unwrap_err();
        assert_eq!(unknown.code, "usage");
        assert!(unknown.hint.unwrap().contains("--if-exists"));
        let bad = build(&tool(), None, &flags(&[("sets", Some("three"))]), cwd).unwrap_err();
        assert!(bad.message.contains("whole number"));
        let missing = build(&tool(), None, &flags(&[("title", None)]), cwd).unwrap_err();
        assert!(missing.message.contains("needs a value"));
    }

    #[test]
    fn at_prefix_reads_files_and_double_at_is_literal() {
        let directory = std::env::temp_dir().join(format!("tmax-schema-{}", std::process::id()));
        std::fs::create_dir_all(&directory).unwrap();
        std::fs::write(directory.join("note.md"), "# Cue\nBrace.").unwrap();
        let built = build(&tool(), None, &flags(&[("title", Some("@note.md"))]), &directory).unwrap();
        assert_eq!(built["title"], "# Cue\nBrace.");
        let literal = build(&tool(), None, &flags(&[("title", Some("@@handle"))]), &directory).unwrap();
        assert_eq!(literal["title"], "@handle");
        assert!(build(&tool(), None, &flags(&[("title", Some("@missing.md"))]), &directory).is_err());
    }

    #[test]
    fn path_arguments_are_absolutized_but_urls_are_left_alone() {
        let cwd = Path::new("/work/session");
        let mut arguments = json!({
            "cover": "shots/a.png",
            "media": [{"path": "clip.mp4", "comment": "keep"}, {"path": "/abs/b.jpg"}]
        });
        let schema = tool();
        absolutize(&mut arguments, &schema["inputSchema"], cwd, &[]);
        assert_eq!(arguments["cover"], "/work/session/shots/a.png");
        assert_eq!(arguments["media"][0]["path"], "/work/session/clip.mp4");
        assert_eq!(arguments["media"][0]["comment"], "keep");
        assert_eq!(arguments["media"][1]["path"], "/abs/b.jpg");
        let mut link = json!({"cover": "https://example.com/x.png"});
        absolutize(&mut link, &schema["inputSchema"], cwd, &[]);
        assert_eq!(link["cover"], "https://example.com/x.png");
    }

    #[test]
    fn batch_operations_are_absolutized_with_the_inner_tool_schema() {
        let catalog = vec![tool(), json!({"name": "batch", "inputSchema": {"type": "object", "properties": {"operations": {"type": "array", "items": {"type": "object"}}}}})];
        let mut arguments = json!({"operations": [
            {"tool": "create_exercise_page", "arguments": {"title": "A", "media": [{"path": "a.jpg"}]}}
        ]});
        absolutize_call(&catalog[1], &mut arguments, Path::new("/w"), &catalog);
        assert_eq!(arguments["operations"][0]["arguments"]["media"][0]["path"], "/w/a.jpg");
    }

    #[test]
    fn kebab_names_round_trip_through_normalization() {
        assert_eq!(kebab("ifExists"), "if-exists");
        assert_eq!(kebab("new_parent"), "new-parent");
        assert_eq!(kebab("linkURLs"), "link-urls");
        assert_eq!(normalize("--link-urls"), normalize("linkURLs"));
        assert_eq!(normalize("--if-exists"), normalize("ifExists"));
    }

    #[test]
    fn bare_paths_become_media_objects_while_json_is_still_accepted() {
        let cwd = Path::new("/");
        let built = build(
            &tool(),
            None,
            &flags(&[("media", Some("a.jpg")), ("media", Some("clip.mp4")), ("media", Some(r#"{"path":"c.png","comment":"x"}"#))]),
            cwd,
        )
        .unwrap();
        assert_eq!(built["media"], json!([{"path": "a.jpg"}, {"path": "clip.mp4"}, {"path": "c.png", "comment": "x"}]));
    }
}
